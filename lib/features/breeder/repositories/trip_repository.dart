import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

  /// When the breeder tapped "Arrived" (null if they haven't).
  final DateTime? arrivedAt;

  TripLocation({
    required this.bookingId,
    required this.breederId,
    required this.farmerId,
    required this.latitude,
    required this.longitude,
    required this.active,
    this.arrivedAt,
  });

  bool get arrived => arrivedAt != null;

  factory TripLocation.fromJson(Map<String, dynamic> json, String id) {
    return TripLocation(
      bookingId: id,
      breederId: json['breederId'] as String? ?? '',
      farmerId: json['farmerId'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      active: json['active'] as bool? ?? false,
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

  /// Marks the trip as started. Doesn't need a GPS fix: the trip map draws
  /// both pinned farm locations, so the farmer sees "on the way" even when
  /// the breeder's phone can't get a location.
  Future<void> startTrip({
    required String bookingId,
    required String breederId,
    required String farmerId,
  }) {
    return _firestore.collection('trip_locations').doc(bookingId).set({
      'breederId': breederId,
      'farmerId': farmerId,
      'active': true,
      // A restarted trip is no longer "arrived".
      'arrivedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateLocation({
    required String bookingId,
    required String breederId,
    required String farmerId,
    required double latitude,
    required double longitude,
  }) {
    return _firestore.collection('trip_locations').doc(bookingId).set({
      'breederId': breederId,
      'farmerId': farmerId,
      'latitude': latitude,
      'longitude': longitude,
      'active': true,
      // A restarted trip is no longer "arrived".
      'arrivedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  TripTrackingController(this._repository);

  bool get isTrackingBooking => _activeBookingId != null;
  String? get activeBookingId => _activeBookingId;

  Future<void> startTrip({
    required String bookingId,
    required String breederId,
    required String farmerId,
  }) async {
    await stopTrip();

    // Mark the trip live first; errors here (e.g. offline) reach the caller.
    await _repository.startTrip(
      bookingId: bookingId,
      breederId: breederId,
      farmerId: farmerId,
    );

    _activeBookingId = bookingId;
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
          _repository.updateLocation(
            bookingId: bookingId,
            breederId: breederId,
            farmerId: farmerId,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }, onError: (Object e) => debugPrint('Trip position stream error: $e'));

    // Push an immediate fix so the farmer isn't waiting on the first
    // distanceFilter-triggered update.
    try {
      final initial = await Geolocator.getCurrentPosition();
      await _repository.updateLocation(
        bookingId: bookingId,
        breederId: breederId,
        farmerId: farmerId,
        latitude: initial.latitude,
        longitude: initial.longitude,
      );
    } catch (e) {
      debugPrint('Failed to get initial trip position: $e');
    }
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
