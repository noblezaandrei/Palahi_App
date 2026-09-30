import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palahi/core/utils/date_utils.dart';
import '../../models/stud_pig_model.dart';
import '../../repositories/breeding_request_repository.dart';

/// Why [pig] can't be booked right now ("Not available", "No open dates" or
/// "Fully booked"), or null if it can. A pig is fully booked once it's taken
/// on every one of the breeder's upcoming [availableDates] — it breeds at
/// most once a day.
String? pigUnavailableReason(
  StudPigModel pig,
  List<String> availableDates,
  Set<String> bookedDates,
) {
  if (!pig.isAvailable) return 'Not available';

  final today = dateKey(DateTime.now());
  // yyyy-MM-dd strings sort by date, so a string compare finds upcoming days.
  final upcomingDates = availableDates
      .where((d) => d.compareTo(today) >= 0)
      .toSet();
  if (upcomingDates.isEmpty) return 'No open dates';
  if (upcomingDates.difference(bookedDates).isEmpty) return 'Fully booked';
  return null;
}

/// Builds a pig card knowing whether the pig can be booked, from the
/// breeder's bookings (live) — so every screen listing pigs agrees. A card
/// for a pig that can't be booked comes back greyed out.
class PigAvailabilityBuilder extends ConsumerWidget {
  final StudPigModel pig;
  final List<String> availableDates;

  /// [unavailableReason] is null when the pig can be booked.
  final Widget Function(BuildContext context, String? unavailableReason)
  builder;

  const PigAvailabilityBuilder({
    super.key,
    required this.pig,
    required this.availableDates,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Until bookings load, the pig shows as bookable; the date picker
    // re-checks on the server anyway.
    final bookedDates =
        ref
            .watch(breederPigBookedDatesProvider(pig.breederId))
            .value?[pig.id] ??
        const <String>{};
    final reason = pigUnavailableReason(pig, availableDates, bookedDates);
    final card = builder(context, reason);
    if (reason == null) return card;

    // Faded and in greyscale so it reads as unbookable at a glance.
    return Opacity(
      opacity: 0.55,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        child: card,
      ),
    );
  }
}
