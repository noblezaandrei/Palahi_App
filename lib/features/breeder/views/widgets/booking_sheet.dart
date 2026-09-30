import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
import '../../../../core/widgets/pig_icon.dart';
import '../../../auth/repositories/auth_repository.dart';
import '../../models/breeder_model.dart';
import '../../models/breeding_request_model.dart';
import '../../models/stud_pig_model.dart';
import '../../repositories/breeder_repository.dart';
import '../../repositories/breeding_request_repository.dart';
import '../../repositories/stud_pig_repository.dart';
import 'package:palahi/core/widgets/pig_loader.dart';
import 'package:palahi/core/l10n/app_strings.dart';
import 'package:palahi/core/utils/provider_utils.dart';

/// Opens the sheet where a farmer books [pig] from [breeder]: breeding
/// type, one of the breeder's open dates, and a free hourly time. With
/// [reschedule], it moves that existing booking to a new date and time
/// instead.
Future<void> showBookingSheet(
  BuildContext context, {
  required BreederModel breeder,
  required StudPigModel pig,
  required String farmerName,
  BreedingRequestModel? reschedule,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => BookingSheet(
      breeder: breeder,
      pig: pig,
      farmerName: farmerName,
      reschedule: reschedule,
    ),
  );
}

/// Opens the reschedule sheet for the farmer's [booking], looking up its
/// breeder and stud pig.
Future<void> showRescheduleSheet(
  BuildContext context,
  WidgetRef ref,
  BreedingRequestModel booking,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final breeders = await readFuture(ref, breedersStreamProvider.future);
  final pigs = await readFuture(ref, allAvailablePigsProvider.future);
  final breeder = breeders.where((b) => b.id == booking.breederId).firstOrNull;
  final pig = pigs.where((p) => p.id == booking.studPigId).firstOrNull;
  if (breeder == null || pig == null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${booking.studPigName} isn\'t taking bookings right now, so this '
          'booking can\'t be moved. You can message the breeder or cancel it.',
        ),
      ),
    );
    return;
  }
  if (!context.mounted) return;
  await showBookingSheet(
    context,
    breeder: breeder,
    pig: pig,
    farmerName: booking.farmerName,
    reschedule: booking,
  );
}

class BookingSheet extends ConsumerStatefulWidget {
  final BreederModel breeder;
  final StudPigModel pig;
  final String farmerName;

  /// The booking being moved, when rescheduling rather than booking anew.
  final BreedingRequestModel? reschedule;

  const BookingSheet({
    super.key,
    required this.breeder,
    required this.pig,
    required this.farmerName,
    this.reschedule,
  });

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  final _notesController = TextEditingController();
  late final List<String> _breedingTypes;
  late String _selectedType;

  /// Days this pig is already booked — a pig breeds at most once a day.
  late Future<Set<String>> _pigBookedDates;

  DateTime? _selectedDate;
  String? _selectedTime;

  /// Set when the time the farmer picked gets booked by someone else while
  /// the sheet is open.
  String? _lostTime;

  // Blocks a double tap on the button from sending two requests.
  bool _submitting = false;

  final _dateKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    // Only the services this pig actually offers.
    final service = widget.pig.serviceType.trim().toLowerCase();
    final offersNatural = !service.contains('artificial');
    final offersAI = service == 'both' || service.contains('artificial');
    _breedingTypes = [
      if (offersNatural) 'Manual Breeding',
      if (offersAI) 'Artificial Insemination (AI)',
    ];
    _selectedType = _breedingTypes.first;
    _loadBookedDates();
  }

  void _loadBookedDates() {
    _pigBookedDates = ref
        .read(breedingRequestRepositoryProvider)
        .getBookedDatesForPig(
          widget.pig.id,
          exceptBookingId: widget.reschedule?.id,
        )
        .withNetworkTimeout();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// The breeder's open days from today on, excluding today once its last
  /// slot has started.
  List<DateTime> get _upcomingOpenDates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return widget.breeder.availableDates
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .where((d) => !d.isBefore(today))
        .where((d) => !timeSlotHasPassed(d, bookingTimeSlots.last))
        .toList()
      ..sort();
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
      _lostTime = null;
    });
    // Bring a date picked from the calendar into view in the strip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _dateKeys[dateKey(date)]?.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  Future<void> _openCalendar(List<DateTime> open, Set<String> booked) async {
    bool isBookable(DateTime d) =>
        widget.breeder.availableDates.contains(dateKey(d)) &&
        !booked.contains(dateKey(d)) &&
        !timeSlotHasPassed(d, bookingTimeSlots.last);
    final bookable = open.where(isBookable).toList();
    if (bookable.isEmpty) return;

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      // Must itself satisfy selectableDayPredicate, otherwise showDatePicker
      // throws and never opens.
      initialDate: _selectedDate ?? bookable.first,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: bookable.last,
      selectableDayPredicate: isBookable,
    );
    if (date != null && mounted) _selectDate(date);
  }

  Future<void> _submit() async {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) return;
    final messenger = ScaffoldMessenger.of(context);

    if (timeSlotHasPassed(date, time)) {
      _showError(
        'That time has already passed. Please pick a later time or another '
        'date.',
      );
      return;
    }
    final moving = widget.reschedule;
    if (moving != null &&
        moving.bookingDate == dateKey(date) &&
        moving.bookingTime == time) {
      _showError('That\'s already this booking\'s time. Pick a new one.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw const AppException('You are not logged in.');
      // The farmer's uploaded profile photo, so the breeder sees it on the
      // request and trip map; Google photo as fallback.
      final profilePhoto =
          ref.read(currentUserProfileProvider).value?['imageUrl'] as String? ??
          '';
      final formattedDate = dateKey(date);
      final repository = ref.read(breedingRequestRepositoryProvider);

      final conflict = await repository
          .checkBookingConflict(
            studPigId: widget.pig.id,
            breederId: widget.breeder.id,
            date: formattedDate,
            time: time,
            exceptBookingId: moving?.id,
          )
          .withNetworkTimeout();
      if (conflict == BookingConflict.pigBookedThatDay) {
        throw const SlotTakenException();
      }
      if (conflict == BookingConflict.timeTaken) {
        throw const TimeTakenException();
      }

      if (moving != null) {
        await repository
            .rescheduleRequest(moving, date: formattedDate, time: time)
            .withNetworkTimeout();
        if (!mounted) return;
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Moved to ${formatShortDate(date)} at '
              '${displayBookingTime(time)}. The breeder will confirm the new '
              'time.',
            ),
          ),
        );
        return;
      }

      await repository
          .sendRequest(
            BreedingRequestModel(
              id: '',
              farmerId: user.uid,
              farmerName: widget.farmerName,
              farmerImageUrl: profilePhoto.isNotEmpty
                  ? profilePhoto
                  : user.photoURL ?? '',
              breederId: widget.breeder.id,
              breederName: widget.breeder.farmName,
              breederImageUrl: widget.breeder.imageUrl,
              studPigId: widget.pig.id,
              studPigName: widget.pig.name,
              studPigImageUrl: widget.pig.imageUrl,
              status: 'pending',
              breedingType: _selectedType,
              bookingDate: formattedDate,
              bookingTime: time,
              notes: _notesController.text.trim(),
              createdAt: DateTime.now(),
            ),
          )
          .withNetworkTimeout();

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Booking request sent for ${formatShortDate(date)} at '
            '${displayBookingTime(time)}.',
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Booking request failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      if (e is SlotTakenException) {
        // The pig's day is gone; refresh the strip so it shows as booked.
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
          _loadBookedDates();
        });
      } else if (e is TimeTakenException) {
        setState(() => _selectedTime = null);
      }
      _showError(friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.event_busy, color: AppColors.error),
        title: const Text('Can\'t book that yet'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PigHeader(
                      pig: widget.pig,
                      breeder: widget.breeder,
                      rescheduling: widget.reschedule != null,
                    ),
                    if (widget.reschedule == null) _PigProfile(pig: widget.pig),
                    if (widget.reschedule case final moving?) ...[
                      const SizedBox(height: 14),
                      _InfoBox(
                        icon: Icons.event_repeat,
                        color: AppColors.primary,
                        text:
                            'Now: ${formatBookingSchedule(moving.bookingDate, moving.bookingTime)}. '
                            'Pick a new date and time — the breeder will be '
                            'asked to confirm it.',
                      ),
                    ],
                    if (widget.reschedule == null &&
                        _breedingTypes.length > 1) ...[
                      _SectionTitle(
                        icon: Icons.science_outlined,
                        title: tr('Breeding type'),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final type in _breedingTypes)
                            ChoiceChip(
                              label: Text(type),
                              selected: _selectedType == type,
                              onSelected: (_) =>
                                  setState(() => _selectedType = type),
                            ),
                        ],
                      ),
                    ],
                    _buildDateSection(),
                    _buildTimeSection(),
                    if (widget.reschedule == null) ...[
                      _SectionTitle(
                        icon: Icons.edit_note,
                        title: tr('Notes for the breeder'),
                        trailing: Text(
                          tr('Optional'),
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextField(
                        controller: _notesController,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'e.g. number of sows, farm directions…',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    if (widget.breeder.availableDates.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.calendar_month, title: tr('Choose a date')),
          _InfoBox(
            icon: Icons.event_busy,
            text: 'This breeder hasn\'t opened any dates for booking yet.',
          ),
        ],
      );
    }

    return FutureBuilder<Set<String>>(
      future: _pigBookedDates,
      builder: (context, snapshot) {
        final open = _upcomingOpenDates;
        final booked = snapshot.data ?? const <String>{};

        Widget body;
        if (snapshot.hasError) {
          body = _InfoBox(
            icon: Icons.wifi_off,
            text: 'Could not load dates: ${friendlyError(snapshot.error!)}',
            action: TextButton(
              onPressed: () => setState(_loadBookedDates),
              child: const Text('Retry'),
            ),
          );
        } else if (!snapshot.hasData) {
          body = const SizedBox(
            height: 84,
            child: Center(child: PigLoader(size: 30)),
          );
        } else if (open.isEmpty ||
            open.every((d) => booked.contains(dateKey(d)))) {
          body = _InfoBox(
            icon: Icons.event_busy,
            text: open.isEmpty
                ? 'This breeder has no upcoming open dates.'
                : '${widget.pig.name} is already booked on all of this '
                      'breeder\'s upcoming open dates.',
          );
        } else {
          body = SizedBox(
            height: MediaQuery.textScalerOf(context).scale(84),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: open.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final date = open[index];
                final key = dateKey(date);
                return _DateCard(
                  key: _dateKeys.putIfAbsent(key, GlobalKey.new),
                  date: date,
                  selected:
                      _selectedDate != null && dateKey(_selectedDate!) == key,
                  booked: booked.contains(key),
                  onTap: () => _selectDate(date),
                );
              },
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.calendar_month,
              title: tr('Choose a date'),
              trailing: snapshot.hasData && open.isNotEmpty
                  ? TextButton.icon(
                      onPressed: () => _openCalendar(open, booked),
                      icon: const Icon(Icons.event, size: 18),
                      label: const Text('Calendar'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : null,
            ),
            body,
          ],
        );
      },
    );
  }

  Widget _buildTimeSection() {
    final date = _selectedDate;
    final title = _SectionTitle(
      icon: Icons.schedule,
      title: tr('Choose a time'),
      trailing: date == null ? null : const _SlotLegend(),
    );
    if (date == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          _InfoBox(
            icon: Icons.touch_app_outlined,
            text: tr('Pick a date first to see which times are still open.'),
          ),
        ],
      );
    }

    final day = (
      breederId: widget.breeder.id,
      date: dateKey(date),
      exceptBookingId: widget.reschedule?.id,
    );
    // If someone else books the time this farmer picked, drop it and say so
    // instead of letting them submit a doomed request.
    ref.listen(breederTakenTimesProvider(day), (_, next) {
      final taken = next.value;
      if (taken != null && _selectedTime != null) {
        if (taken.contains(_selectedTime)) {
          setState(() {
            _lostTime = _selectedTime;
            _selectedTime = null;
          });
        }
      }
    });
    final takenAsync = ref.watch(breederTakenTimesProvider(day));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        if (_lostTime != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InfoBox(
              icon: Icons.info_outline,
              color: Colors.orange.shade800,
              text:
                  '${displayBookingTime(_lostTime!)} was just booked by '
                  'another farmer. Please pick a different time.',
            ),
          ),
        takenAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: PigLoader(size: 30)),
          ),
          error: (e, _) => _InfoBox(
            icon: Icons.wifi_off,
            text: 'Could not load open times: ${friendlyError(e)}',
          ),
          data: (taken) {
            final allGone = bookingTimeSlots.every(
              (slot) => taken.contains(slot) || timeSlotHasPassed(date, slot),
            );
            if (allGone) {
              return _InfoBox(
                icon: Icons.event_busy,
                text: tr(
                  'Every time on this day is already booked. Please pick another date.',
                ),
              );
            }
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                // Grows with the phone's font size, so a booked slot's two
                // lines always fit.
                mainAxisExtent: MediaQuery.textScalerOf(context).scale(58),
              ),
              children: [
                for (final slot in bookingTimeSlots)
                  TimeSlotTile(
                    time: slot,
                    state: taken.contains(slot)
                        ? TimeSlotState.booked
                        : timeSlotHasPassed(date, slot)
                        ? TimeSlotState.passed
                        : slot == _selectedTime
                        ? TimeSlotState.selected
                        : TimeSlotState.open,
                    onTap: () => setState(() {
                      _selectedTime = slot;
                      _lostTime = null;
                    }),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final ready = _selectedDate != null && _selectedTime != null;
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready
                          ? '${formatShortDate(_selectedDate!)} · '
                                '${displayBookingTime(_selectedTime!)}'
                          : tr('No time chosen yet'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ready ? AppColors.textDark : AppColors.textLight,
                      ),
                    ),
                    Text(
                      tr('{fee} stud fee · pay cash', {
                        'fee': '₱${widget.pig.price.toStringAsFixed(0)}',
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: ready && !_submitting ? _submit : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _submitting
                      ? 'Sending…'
                      : widget.reschedule != null
                      ? tr('Reschedule')
                      : tr('Book'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PigHeader extends StatelessWidget {
  final StudPigModel pig;
  final BreederModel breeder;
  final bool rescheduling;

  const _PigHeader({
    required this.pig,
    required this.breeder,
    this.rescheduling = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 76,
            height: 76,
            child: pig.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: pig.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const PigPlaceholder(),
                  )
                : const PigPlaceholder(),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(rescheduling ? 'Reschedule {pig}' : 'Book {pig}', {
                  'pig': pig.name,
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${pig.breed} · ${pig.ageMonths} mo · '
                '${pig.weight.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.storefront,
                    size: 14,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      breeder.farmName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '₱${pig.price.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final Widget? action;

  const _InfoBox({
    required this.icon,
    required this.text,
    this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: tint, fontSize: 13)),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool booked;
  final VoidCallback onTap;

  const _DateCard({
    super.key,
    required this.date,
    required this.selected,
    required this.booked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? Colors.white
        : booked
        ? Colors.grey.shade400
        : AppColors.textDark;
    return Material(
      color: selected
          ? AppColors.primary
          : booked
          ? Colors.grey.shade100
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : booked
              ? Colors.grey.shade200
              : AppColors.primaryLighter,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: booked ? null : onTap,
        child: SizedBox(
          width: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayShort(date).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white70 : AppColors.textLight,
                ),
              ),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                  decoration: booked ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                booked ? 'Booked' : monthShort(date),
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white70 : AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum TimeSlotState { open, selected, booked, passed }

/// One hourly slot in the booking sheet. Booked and passed slots can't be
/// tapped and say why.
class TimeSlotTile extends StatelessWidget {
  final String time;
  final TimeSlotState state;
  final VoidCallback onTap;

  const TimeSlotTile({
    super.key,
    required this.time,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unavailable =
        state == TimeSlotState.booked || state == TimeSlotState.passed;
    final selected = state == TimeSlotState.selected;
    final background = selected
        ? AppColors.primary
        : state == TimeSlotState.booked
        ? const Color(0xFFFDECEA)
        : unavailable
        ? Colors.grey.shade100
        : Colors.white;
    final foreground = selected
        ? Colors.white
        : state == TimeSlotState.booked
        ? const Color(0xFFC62828)
        : unavailable
        ? Colors.grey.shade400
        : AppColors.textDark;

    return Semantics(
      button: !unavailable,
      selected: selected,
      label:
          '${displayBookingTime(time)}, '
          '${switch (state) {
            TimeSlotState.booked => 'already booked',
            TimeSlotState.passed => 'already passed',
            TimeSlotState.selected => 'selected',
            TimeSlotState.open => 'open',
          }}',
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? AppColors.primary
                : state == TimeSlotState.booked
                ? const Color(0xFFF5C6C2)
                : unavailable
                ? Colors.grey.shade200
                : AppColors.primaryLighter,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: unavailable ? null : onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayBookingTime(time),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: foreground,
                  decoration: unavailable ? TextDecoration.lineThrough : null,
                  decorationColor: foreground,
                ),
              ),
              if (unavailable)
                Text(
                  tr(state == TimeSlotState.booked ? 'Booked' : 'Passed'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotLegend extends StatelessWidget {
  const _SlotLegend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color fill, Color border, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
        ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(Colors.white, AppColors.primaryLight, tr('Open')),
        const SizedBox(width: 10),
        dot(const Color(0xFFFDECEA), const Color(0xFFF5C6C2), tr('Booked')),
      ],
    );
  }
}

/// The stud pig's photos, description and health records, so a farmer can
/// judge the boar before booking.
class _PigProfile extends StatelessWidget {
  final StudPigModel pig;

  const _PigProfile({required this.pig});

  @override
  Widget build(BuildContext context) {
    final photos = pig.allPhotos;
    final checked = DateTime.tryParse(pig.lastHealthCheck);
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.length > 1) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => showFullScreenImage(context, photos[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 120,
                    child: CachedNetworkImage(
                      imageUrl: photos[i],
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const LoadingPulse(),
                      errorWidget: (_, _, _) => const PigPlaceholder(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (pig.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(pig.description, style: const TextStyle(fontSize: 13)),
        ],
        if (pig.hasHealthInfo)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.primaryBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (pig.vaccinations.isNotEmpty)
                  row(
                    Icons.vaccines_outlined,
                    tr('Vaccinations'),
                    pig.vaccinations,
                  ),
                if (checked != null)
                  row(
                    Icons.event_available_outlined,
                    tr('Health check'),
                    '${formatShortDate(checked)}, ${checked.year}',
                  ),
                if (pig.pedigree.isNotEmpty)
                  row(
                    Icons.account_tree_outlined,
                    tr('Pedigree'),
                    pig.pedigree,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
