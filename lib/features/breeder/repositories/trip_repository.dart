import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../map/repositories/route_service.dart';
import '../../auth/repositories/auth_repository.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(FirebaseFirestore.instance);
});

/// Streams the live trip state for a booking (null if the breeder has never
/// started a trip for it).
final tripLocationStreamProvider = StreamProvider.family<TripLocation?, String>(
  (ref, bookingId) {
    ref.watch(authStateProvider);
    return ref.watch(tripRepositoryProvider).watchTrip(bookingId);
  },
);

/// Keeps a live position stream running (foreground only) for whichever
/// booking the breeder has started a trip for, independent of which screen
/// is currently open — a plain (non-autoDispose) provider so it survives
/// navigation for as long as the app process is alive.
final tripTrackingControllerProvider = Provider<TripTrackingController>((ref) {
  final controller = TripTrackingController(ref.watch(tripRepositoryProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

class TripLocation {
  final String bookingId;
  final String breederId;
  final String farmerId;
  final double latitude;
  final double longitude;
  final bool active;

  /// How far along the route between the two farm pins the breeder has
  /// got: the route point their phone last reached (see
  /// [TripTrackingController]). Null until they've moved along it.
  final LatLng? onRoute;

  /// When the breeder tapped "Arrived" (null if they haven't).
  final DateTime? arrivedAt;

  TripLocation({
    required this.bookingId,
    required this.breederId,
    required this.farmerId,
    required this.latitude,
    required this.longitude,
    required this.active,
    this.onRoute,
    this.arrivedAt,
  });

  bool get arrived => arrivedAt != null;

  factory TripLocation.fromJson(Map<String, dynamic> json, String id) {
    final onRouteLat = (json['onRouteLatitude'] as num?)?.toDouble();
    final onRouteLng = (json['onRouteLongitude'] as num?)?.toDouble();
    return TripLocation(
      bookingId: id,
      breederId: json['breederId'] as String? ?? '',
      farmerId: json['farmerId'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      active: json['active'] as bool? ?? false,
      onRoute: onRouteLat != null && onRouteLng != null
          ? LatLng(onRouteLat, onRouteLng)
          : null,
      arrivedAt: (json['arrivedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class TripRepository {
  final FirebaseFirestore _firestore;

  TripRepository(this._firestore);

  Stream<TripLocation?> watchTrip(String bookingId) async* {
    try {
      await for (final doc
          in _firestore
              .collection('trip_locations')
              .doc(bookingId)
              .snapshots()) {
        yield doc.exists ? TripLocation.fromJson(doc.data()!, doc.id) : null;
      }
    } catch (error) {
      debugPrint('Failed to watch trip location: $error');
      yield null;
    }
  }

  /// Marks the trip as started. Doesn't need a GPS fix: until the first one
  /// arrives the trip map starts the breeder at their pinned farm, so the
  /// farmer sees "on the way" even when the breeder's phone can't get a
  /// location.
  Future<void> startTrip({
    required String bookingId,
    required String breederId,
    required String farmerId,
  }) {
    return _firestore.collection('trip_locations').doc(bookingId).set({
      'breederId': breederId,
      'farmerId': farmerId,
      'active': true,
      // A restarted trip is no longer "arrived", and the last trip's final
      // position (at this farm) mustn't show as where the breeder is now.
      'arrivedAt': null,
      'latitude': FieldValue.delete(),
      'longitude': FieldValue.delete(),
      'onRouteLatitude': FieldValue.delete(),
      'onRouteLongitude': FieldValue.delete(),
      // Left by earlier app versions.
      'routeFromLatitude': FieldValue.delete(),
      'routeFromLongitude': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Saves the breeder's latest position, plus [onRoute] when they've got
  /// further along the trip's route (merged, so the last progress stays).
  Future<void> updateLocation({
    required String bookingId,
    required String breederId,
    required String farmerId,
    required double latitude,
    required double longitude,
    LatLng? onRoute,
  }) {
    return _firestore.collection('trip_locations').doc(bookingId).set({
      'breederId': breederId,
      'farmerId': farmerId,
      'latitude': latitude,
      'longitude': longitude,
      if (onRoute != null) ...{
        'onRouteLatitude': onRoute.latitude,
        'onRouteLongitude': onRoute.longitude,
      },
      'active': true,
      // A restarted trip is no longer "arrived".
      'arrivedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Notifies the farmer about their booking's trip — in the app and, via
  /// the pushOnNotification Cloud Function, on their phone. Best effort: the
  /// trip itself has already been saved.
  Future<void> notifyFarmer({
    required String bookingId,
    required String farmerId,
    required String title,
    required String body,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': farmerId,
        'title': title,
        'body': body,
        'type': 'booking',
        'referenceId': bookingId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to notify farmer about the trip: $e');
    }
  }

  /// Ends the live trip. [arrived] records that the breeder reached the farm,
  /// which the farmer sees on their breeding request and trip map.
  /// [breederId]/[farmerId] let this create the document if it doesn't
  /// exist yet (the security rules require breederId on create).
  Future<void> endTrip(
    String bookingId, {
    bool arrived = false,
    String? breederId,
    String? farmerId,
  }) {
    return _firestore.collection('trip_locations').doc(bookingId).set({
      'breederId': ?breederId,
      'farmerId': ?farmerId,
      'active': false,
      if (arrived) 'arrivedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class TripTrackingController {
  final TripRepository _repository;
  StreamSubscription<Position>? _subscription;
  String? _activeBookingId;

  // The trip's road route, always from the breeder's farm pin to the
  // farmer's, and how far along it the breeder has got. The phone saves that
  // progress on the trip, so both phones draw the icon at the same spot on
  // the same fixed route.
  RoadRoute? _route;
  int _reachedIndex = 0;

  TripTrackingController(this._repository);

  bool get isTrackingBooking => _activeBookingId != null;
  String? get activeBookingId => _activeBookingId;

  Future<void> startTrip({
    required String bookingId,
    required String breederId,
    required String farmerId,
    LatLng? farmPoint,
    LatLng? breederPin,
  }) async {
    await stopTrip();

    // Mark the trip live first; errors here (e.g. offline) reach the caller.
    await _repository.startTrip(
      bookingId: bookingId,
      breederId: breederId,
      farmerId: farmerId,
    );
    _track(
      bookingId: bookingId,
      breederId: breederId,
      farmerId: farmerId,
      farmPoint: farmPoint,
      breederPin: breederPin,
    );
  }

  /// Picks a live trip back up after the app was closed or restarted mid-
  /// trip — which ends the location stream — without resetting it: the
  /// breeder keeps the progress [reached] they'd already made.
  void resumeTrip({
    required String bookingId,
    required String breederId,
    required String farmerId,
    LatLng? farmPoint,
    LatLng? breederPin,
    LatLng? reached,
  }) {
    if (_activeBookingId == bookingId) return;
    _subscription?.cancel();
    _track(
      bookingId: bookingId,
      breederId: breederId,
      farmerId: farmerId,
      farmPoint: farmPoint,
      breederPin: breederPin,
      reached: reached,
    );
  }

  void _track({
    required String bookingId,
    required String breederId,
    required String farmerId,
    LatLng? farmPoint,
    LatLng? breederPin,
    LatLng? reached,
  }) {
    _activeBookingId = bookingId;
    _route = null;
    _reachedIndex = 0;
    if (farmPoint != null && breederPin != null) {
      // The same (cached) lookup the trip map makes for these two pins.
      fetchTripRoute(routeKeyFor(breederPin, farmPoint)).then((route) {
        if (_activeBookingId != bookingId || route == null) return;
        _route = route;
        if (reached != null) {
          // Carry on from where the breeder had got to.
          _reachedIndex =
              progressAlongRoute(route, reached, reachedIndex: -1) ?? 0;
        }
      });
    }

    _subscription =
        Geolocator.getPositionStream(
          locationSettings: _tripLocationSettings,
        ).listen((position) {
          if (_activeBookingId != bookingId) return; // trip already ended
          _repository.updateLocation(
            bookingId: bookingId,
            breederId: breederId,
            farmerId: farmerId,
            latitude: position.latitude,
            longitude: position.longitude,
            onRoute: _progress(position),
          );
        }, onError: (Object e) => debugPrint('Trip position stream error: $e'));

    // Push an immediate fix so the farmer isn't waiting on the first
    // distanceFilter-triggered update. Not awaited: a GPS fix can take a
    // while indoors, and the trip has already started.
    unawaited(_pushInitialFix(bookingId, breederId, farmerId));
  }

  /// On Android the location stream runs as a foreground service with an
  /// ongoing "Trip in progress" notification, so it keeps going while the
  /// phone is locked or the breeder switches apps (otherwise Android pauses
  /// it and the farmer's map freezes). It stops when the trip ends.
  static final LocationSettings _tripLocationSettings =
      defaultTargetPlatform == TargetPlatform.android
      ? AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Trip in progress',
            notificationText:
                'PALAHI is sharing your location with the farmer until you '
                'tap Arrived.',
            notificationChannelName: 'Trip tracking',
            notificationIcon: AndroidResource(
              name: 'ic_stat_palahi',
              defType: 'drawable',
            ),
            enableWakeLock: true,
            setOngoing: true,
            color: Color(0xFF2E7D32),
          ),
        )
      : const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        );

  Future<void> _pushInitialFix(
    String bookingId,
    String breederId,
    String farmerId,
  ) async {
    try {
      final initial = await Geolocator.getCurrentPosition();
      // If "Arrived" was tapped while waiting for the fix, writing it now
      // would mark the trip active again and erase the arrival.
      if (_activeBookingId != bookingId) return;
      await _repository.updateLocation(
        bookingId: bookingId,
        breederId: breederId,
        farmerId: farmerId,
        latitude: initial.latitude,
        longitude: initial.longitude,
        onRoute: _progress(initial),
      );
    } catch (e) {
      debugPrint('Failed to get initial trip position: $e');
    }
  }

  /// The route point the breeder has now reached, if [position] moved them
  /// further along the trip's route; null to leave their icon where it is.
  LatLng? _progress(Position position) {
    final route = _route;
    if (route == null) return null; // still looking it up
    final index = progressAlongRoute(
      route,
      LatLng(position.latitude, position.longitude),
      reachedIndex: _reachedIndex,
    );
    if (index == null) return null;
    _reachedIndex = index;
    return route.points[index];
  }

  Future<void> stopTrip({bool arrived = false}) async {
    await _subscription?.cancel();
    _subscription = null;
    if (_activeBookingId != null) {
      final bookingId = _activeBookingId!;
      _activeBookingId = null;
      await _repository.endTrip(bookingId, arrived: arrived);
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
