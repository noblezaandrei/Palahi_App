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

enum TripMapStatus { loading, error, noFarmPin, waitingForBreeder, ready }

class TripMapState {
  final TripMapStatus status;
  final String? errorMessage;

  /// The breeder this trip is for (empty until known).
  final String breederId;

  /// Whether the breeder has actually started the trip.
  final bool live;
  final LatLng? farmPoint;
  final LatLng? breederPoint;
  final RoadRoute? route;
  final double straightLineKm;

  const TripMapState({
    required this.status,
    this.errorMessage,
    this.breederId = '',
    this.live = false,
    this.farmPoint,
    this.breederPoint,
    this.route,
    this.straightLineKm = 0,
  });

  double get distanceKm => route?.distanceKm ?? straightLineKm;

  String get etaLabel => route != null
      ? formatTripDuration(route!.duration)
      : formatStraightLineEta(straightLineKm);
}

/// View model for the trip map, shared by the farmer (watching the breeder)
/// and the breeder (route preview plus Start Trip / Arrived). Both ends of the
/// route are the pinned farm locations rather than live GPS, and both sides
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
    final breeders = ref.watch(breedersStreamProvider).value ?? [];

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
    final breederId = args.breederId ?? trip?.breederId ?? '';

    LatLng? breederPoint;
    if (live || args.isBreeder) {
      for (final b in breeders) {
        if (b.id == breederId && (b.latitude != 0.0 || b.longitude != 0.0)) {
          breederPoint = LatLng(b.latitude, b.longitude);
        }
      }
    }
    if (breederPoint == null) {
      return TripMapState(
        status: args.isBreeder
            ? TripMapStatus.loading
            : TripMapStatus.waitingForBreeder,
        breederId: breederId,
        live: live,
      );
    }

    final farmPoint = LatLng(farm.latitude, farm.longitude);
    final routeValue = ref
        .watch(tripRouteProvider(routeKeyFor(breederPoint, farmPoint)))
        .value;
    if (routeValue != null) _lastRoute = routeValue;

    return TripMapState(
      status: TripMapStatus.ready,
      breederId: breederId,
      live: live,
      farmPoint: farmPoint,
      breederPoint: breederPoint,
      route: _lastRoute,
      straightLineKm: LocationUtils.getDistanceKm(
        breederPoint.latitude,
        breederPoint.longitude,
        farmPoint.latitude,
        farmPoint.longitude,
      ),
    );
  }

  Future<void> startTrip() {
    return ref
        .read(tripTrackingControllerProvider)
        .startTrip(
          bookingId: args.bookingId,
          breederId: args.breederId!,
          farmerId: args.farmerId,
        );
  }

  Future<void> endTrip() {
    return ref.read(tripTrackingControllerProvider).stopTrip();
  }
}

final tripMapViewModelProvider = NotifierProvider.autoDispose
    .family<TripMapViewModel, TripMapState, TripMapArgs>(TripMapViewModel.new);
