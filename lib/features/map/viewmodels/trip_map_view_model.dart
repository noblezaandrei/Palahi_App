import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:palahi/core/utils/location_utils.dart';
import 'package:palahi/features/breeder/repositories/breeder_repository.dart';
import 'package:palahi/features/breeder/repositories/trip_repository.dart';
import 'package:palahi/features/map/repositories/farmer_location_repository.dart';
import 'package:palahi/features/map/repositories/route_service.dart';

// Straight-line distance understates the real road distance, so when no road
// route is available pad it and assume an average rural driving speed.
const double _roadDetourFactor = 1.3;
const double _averageSpeedKmh = 30;

/// "12 min" or "1 hr 20 min".
String formatTripDuration(Duration d) {
  final minutes = (d.inSeconds / 60).round();
  if (minutes < 1) return 'Less than 1 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}

/// Fallback ETA from a straight-line distance.
String formatStraightLineEta(double straightLineKm) {
  if (straightLineKm < 0.1) return 'Arriving now';
  final minutes = (straightLineKm * _roadDetourFactor / _averageSpeedKmh * 60)
      .round();
  return formatTripDuration(Duration(minutes: minutes));
}

/// Identifies one trip map. [breederId] is set only in the breeder's own view.
class TripMapArgs {
  final String bookingId;
  final String farmerId;
  final String breederName;
  final String? breederId;

  const TripMapArgs({
    required this.bookingId,
    required this.farmerId,
    required this.breederName,
    this.breederId,
  });

  bool get isBreeder => breederId != null;

  @override
  bool operator ==(Object other) =>
      other is TripMapArgs &&
      other.bookingId == bookingId &&
      other.farmerId == farmerId &&
      other.breederName == breederName &&
      other.breederId == breederId;

  @override
  int get hashCode => Object.hash(bookingId, farmerId, breederName, breederId);
}

enum TripMapStatus {
  loading,
  error,
  noFarmPin,
  noBreederPin,
  waitingForBreeder,
  ready,
}

class TripMapState {
  final TripMapStatus status;
  final String? errorMessage;

  /// The breeder this trip is for (empty until known).
  final String breederId;

  /// Whether the breeder has actually started the trip.
  final bool live;

  /// When the breeder marked themselves arrived (null if not yet).
  final DateTime? arrivedAt;
  final LatLng? farmPoint;

  /// Where the breeder is: their phone's live GPS during a trip, otherwise
  /// (or until the first GPS fix) their pinned farm.
  final LatLng? breederPoint;

  /// The breeder's pinned farm, where the trip's route starts.
  final LatLng? breederPin;

  /// The road still ahead of the breeder.
  final RoadRoute? route;

  /// The whole road route as planned, for framing the map; unlike [route]
  /// it doesn't shrink as the breeder drives.
  final RoadRoute? plannedRoute;
  final double straightLineKm;

  const TripMapState({
    required this.status,
    this.errorMessage,
    this.breederId = '',
    this.live = false,
    this.arrivedAt,
    this.farmPoint,
    this.breederPoint,
    this.breederPin,
    this.route,
    this.plannedRoute,
    this.straightLineKm = 0,
  });

  bool get arrived => arrivedAt != null;

  double get distanceKm => route?.distanceKm ?? straightLineKm;

  String get etaLabel => route != null
      ? formatTripDuration(route!.duration)
      : formatStraightLineEta(straightLineKm);
}

/// View model for the trip map, shared by the farmer (watching the breeder)
/// and the breeder (route preview plus Start Trip / Arrived). The farm end is
/// the farmer's pinned location and the route starts at the breeder's pinned
/// farm; while the trip is live the breeder's icon moves along that route as
/// their phone reports progress, so the farmer watches them come closer. Both sides
/// read the same state, so route, distance and ETA always match.
class TripMapViewModel extends Notifier<TripMapState> {
  final TripMapArgs args;

  TripMapViewModel(this.args);

  // Kept while the next route loads so the line doesn't flicker away.
  RoadRoute? _lastRoute;

  @override
  TripMapState build() {
    final farmAsync = ref.watch(farmerLocationProvider(args.farmerId));
    final tripAsync = ref.watch(tripLocationStreamProvider(args.bookingId));
    final breedersAsync = ref.watch(breedersStreamProvider);
    final breeders = breedersAsync.value ?? [];

    if (farmAsync.hasError) {
      return TripMapState(
        status: TripMapStatus.error,
        errorMessage: 'Error loading your farm location: ${farmAsync.error}',
      );
    }
    final farm = farmAsync.value;
    if (farmAsync.isLoading && farm == null) {
      return const TripMapState(status: TripMapStatus.loading);
    }
    if (farm == null) {
      return const TripMapState(status: TripMapStatus.noFarmPin);
    }

    if (tripAsync.hasError) {
      return TripMapState(
        status: TripMapStatus.error,
        errorMessage: 'Error loading trip: ${tripAsync.error}',
      );
    }
    if (tripAsync.isLoading && !tripAsync.hasValue) {
      return const TripMapState(status: TripMapStatus.loading);
    }

    final trip = tripAsync.value;
    final live = trip != null && trip.active;
    final arrivedAt = live ? null : trip?.arrivedAt;
    final breederId = args.breederId ?? trip?.breederId ?? '';

    // The route always runs between the two pinned farms, so it's the same
    // on both phones and never changes during the trip.
    LatLng? breederPin;
    if (live || args.isBreeder) {
      for (final b in breeders) {
        if (b.id == breederId && (b.latitude != 0.0 || b.longitude != 0.0)) {
          breederPin = LatLng(b.latitude, b.longitude);
        }
      }
    }
    if (breederPin == null) {
      final TripMapStatus status;
      if (!live && !args.isBreeder) {
        status = TripMapStatus.waitingForBreeder;
      } else if (!breedersAsync.hasValue) {
        status = TripMapStatus.loading;
      } else {
        // Breeders are loaded but this one never pinned their farm, so
        // there's no start point for the route — say so instead of
        // spinning forever.
        status = TripMapStatus.noBreederPin;
      }
      return TripMapState(
        status: status,
        breederId: breederId,
        live: live,
        arrivedAt: arrivedAt,
      );
    }

    final farmPoint = LatLng(farm.latitude, farm.longitude);
    // The breeder starts at their farm pin, then moves along the route as
    // far as their phone reports they've got.
    final breederPoint = live && trip.onRoute != null
        ? trip.onRoute!
        : breederPin;

    final routeValue = ref
        .watch(tripRouteProvider(routeKeyFor(breederPin, farmPoint)))
        .value;
    if (routeValue != null) _lastRoute = routeValue;

    final plannedRoute = _lastRoute;
    return TripMapState(
      status: TripMapStatus.ready,
      breederId: breederId,
      live: live,
      arrivedAt: arrivedAt,
      farmPoint: farmPoint,
      breederPoint: breederPoint,
      breederPin: breederPin,
      route: plannedRoute != null && live
          ? remainingRoute(plannedRoute, breederPoint).route
          : plannedRoute,
      plannedRoute: plannedRoute,
      straightLineKm: LocationUtils.getDistanceKm(
        breederPoint.latitude,
        breederPoint.longitude,
        farmPoint.latitude,
        farmPoint.longitude,
      ),
    );
  }

  Future<void> startTrip() async {
    final eta = state.status == TripMapStatus.ready ? state.etaLabel : null;
    await ref
        .read(tripTrackingControllerProvider)
        .startTrip(
          bookingId: args.bookingId,
          breederId: args.breederId!,
          farmerId: args.farmerId,
          farmPoint: state.farmPoint,
          breederPin: state.breederPin,
        );
    await ref
        .read(tripRepositoryProvider)
        .notifyFarmer(
          bookingId: args.bookingId,
          farmerId: args.farmerId,
          title: 'Your breeder is on the way',
          body:
              '${_breederName()} has started the trip to your farm'
              '${eta == null ? '' : ' and should arrive in about $eta'}. '
              'Tap to track them.',
        );
  }

  String _breederName() =>
      args.breederName.trim().isEmpty ? 'The breeder' : args.breederName;

  /// Picks the breeder's own live trip back up when their phone isn't
  /// tracking it any more — the app was closed or restarted mid-trip, which
  /// ends the location stream. Keeps the progress already made.
  void resumeIfNeeded() {
    if (!args.isBreeder || !state.live) return;
    if (state.status != TripMapStatus.ready) return;
    final controller = ref.read(tripTrackingControllerProvider);
    if (controller.activeBookingId == args.bookingId) return;
    controller.resumeTrip(
      bookingId: args.bookingId,
      breederId: args.breederId!,
      farmerId: args.farmerId,
      farmPoint: state.farmPoint,
      breederPin: state.breederPin,
      reached: state.breederPoint,
    );
  }

  Future<void> endTrip() async {
    final controller = ref.read(tripTrackingControllerProvider);
    if (controller.activeBookingId == args.bookingId) {
      await controller.stopTrip(arrived: true);
    } else {
      // The app was restarted mid-trip, so the controller isn't tracking this
      // booking any more; still end it so the farmer sees the arrival.
      await ref
          .read(tripRepositoryProvider)
          .endTrip(
            args.bookingId,
            arrived: true,
            breederId: args.breederId,
            farmerId: args.farmerId,
          );
    }
    await ref
        .read(tripRepositoryProvider)
        .notifyFarmer(
          bookingId: args.bookingId,
          farmerId: args.farmerId,
          title: 'Your breeder has arrived',
          body: '${_breederName()} has arrived at your farm.',
        );
  }
}

final tripMapViewModelProvider = NotifierProvider.autoDispose
    .family<TripMapViewModel, TripMapState, TripMapArgs>(TripMapViewModel.new);
