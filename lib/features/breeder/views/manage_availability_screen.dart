import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/breeder_repository.dart';
import '../repositories/breeding_request_repository.dart';
import '../models/breeder_model.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/constants/colors.dart';
import 'package:palahi/core/utils/date_utils.dart';
import 'package:palahi/core/utils/error_messages.dart';
import 'package:palahi/core/widgets/pig_loader.dart';

/// The breeder's availability as a month calendar: tap a day to open or
/// close it for booking, one month at a time, plus a "Repeat weekly"
/// shortcut for regular schedules. A list of dates got too long to scroll.
class ManageAvailabilityScreen extends ConsumerStatefulWidget {
  /// True when shown as a bottom-nav tab, where the home screen already
  /// provides the app bar.
  final bool embeddedInTabs;

  const ManageAvailabilityScreen({super.key, this.embeddedInTabs = false});

  @override
  ConsumerState<ManageAvailabilityScreen> createState() =>
      _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState
    extends ConsumerState<ManageAvailabilityScreen> {
  /// The first day of the month on screen.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _lastOpenableDay =>
      DateTime(_today.year, _today.month, _today.day + availabilityWindowDays);

  Future<void> _run(Future<void> Function() write) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await write().withNetworkTimeout();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not update your calendar: ${friendlyError(e)}'),
        ),
      );
    }
  }

  Future<void> _toggleDay(
    BreederModel breeder,
    String day,
    bool hasBookings,
  ) async {
    final repository = ref.read(breederRepositoryProvider);
    if (!breeder.availableDates.contains(day)) {
      return _run(() => repository.addAvailableDates(breeder.id, [day]));
    }

    // Closing a day doesn't cancel what's already booked on it; say so
    // rather than let the breeder think it did.
    if (hasBookings) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('This day has bookings'),
          content: const Text(
            'Removing it stops new bookings on this day. Bookings you already '
            'have stay as they are — manage them in Requests.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    return _run(() => repository.removeAvailableDate(breeder.id, day));
  }

  Future<void> _repeatWeekly(BreederModel breeder) async {
    final dates = await showDialog<List<String>>(
      context: context,
      builder: (context) =>
          _RepeatWeeklyDialog(today: _today, lastDay: _lastOpenableDay),
    );
    if (dates == null || !mounted) return;

    final newDates = dates
        .where((d) => !breeder.availableDates.contains(d))
        .toList();
    if (newDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Those days are already open.')),
      );
      return;
    }
    await _run(
      () => ref
          .read(breederRepositoryProvider)
          .addAvailableDates(breeder.id, newDates),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opened ${newDates.length} ${newDates.length == 1 ? 'day' : 'days'} '
          'for booking.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final breedersAsync = ref.watch(breedersStreamProvider);
    // Days with an active booking on any of this breeder's pigs.
    final bookedDays = {
      for (final dates
          in (ref.watch(breederPigBookedDatesProvider(user.uid)).value ??
                  const <String, Set<String>>{})
              .values)
        ...dates,
    };

    return Scaffold(
      appBar: widget.embeddedInTabs
          ? null
          : AppBar(title: const Text('Manage Availability')),
      body: breedersAsync.when(
        data: (breeders) {
          final breeder = breeders.firstWhere(
            (b) => b.id == user.uid,
            orElse: () => BreederModel(
              id: user.uid,
              userId: user.uid,
              farmName: '',
              location: '',
              latitude: 0,
              longitude: 0,
              rating: 0,
              reviewCount: 0,
              imageUrl: '',
              about: '',
              services: const [],
            ),
          );
          final available = breeder.availableDates.toSet();
          final monthPrefix = dateKey(_month).substring(0, 8); // yyyy-MM-
          final openThisMonth = available
              .where(
                (d) =>
                    d.startsWith(monthPrefix) &&
                    d.compareTo(dateKey(_today)) >= 0,
              )
              .length;

          final firstMonth = DateTime(_today.year, _today.month);
          final lastMonth = DateTime(
            _lastOpenableDay.year,
            _lastOpenableDay.month,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap a day to open it for booking. Tap it again to close '
                  'it. Farmers can only book you on open days.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _repeatWeekly(breeder),
                    icon: const Icon(Icons.event_repeat),
                    label: const Text('Repeat Weekly'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: _month.isAfter(firstMonth)
                          ? () => setState(
                              () => _month = DateTime(
                                _month.year,
                                _month.month - 1,
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            formatMonthYear(_month),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$openThisMonth open '
                            '${openThisMonth == 1 ? 'day' : 'days'}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: _month.isBefore(lastMonth)
                          ? () => setState(
                              () => _month = DateTime(
                                _month.year,
                                _month.month + 1,
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _MonthGrid(
                  month: _month,
                  today: _today,
                  lastDay: _lastOpenableDay,
                  available: available,
                  bookedDays: bookedDays,
                  onDayTapped: (day) =>
                      _toggleDay(breeder, day, bookedDays.contains(day)),
                ),
                const SizedBox(height: 16),
                const _Legend(),
              ],
            ),
          );
        },
        loading: () => const Center(child: PigLoader()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final DateTime lastDay;
  final Set<String> available;
  final Set<String> bookedDays;
  final void Function(String day) onDayTapped;

  const _MonthGrid({
    required this.month,
    required this.today,
    required this.lastDay,
    required this.available,
    required this.bookedDays,
    required this.onDayTapped,
  });

  static const _weekdayLabels = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Sunday-first: DateTime.weekday is 1 (Mon) … 7 (Sun).
    final leadingBlanks = month.weekday % 7;

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox(),
            for (var d = 1; d <= daysInMonth; d++)
              _buildDay(DateTime(month.year, month.month, d)),
          ],
        ),
      ],
    );
  }

  Widget _buildDay(DateTime date) {
    final key = dateKey(date);
    final isOpen = available.contains(key);
    final isBooked = bookedDays.contains(key);
    final isToday = date == today;
    final selectable = !date.isBefore(today) && !date.isAfter(lastDay);

    final Color background;
    final Color foreground;
    if (!selectable) {
      background = isOpen ? AppColors.primaryLighter : Colors.transparent;
      foreground = Colors.grey.shade400;
    } else if (isOpen) {
      background = AppColors.primary;
      foreground = Colors.white;
    } else {
      background = Colors.grey.shade100;
      foreground = AppColors.textDark;
    }

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isToday
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selectable ? () => onDayTapped(key) : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: foreground,
                fontWeight: isOpen ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isBooked)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isOpen && selectable
                        ? Colors.white
                        : Colors.orange.shade700,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
    Widget box(Color color) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(box(AppColors.primary), 'Open for booking'),
        item(box(Colors.grey.shade100), 'Closed'),
        item(
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              shape: BoxShape.circle,
            ),
          ),
          'Has bookings',
        ),
      ],
    );
  }
}

/// Picks weekdays and a period, and returns the matching dates (yyyy-MM-dd).
class _RepeatWeeklyDialog extends StatefulWidget {
  final DateTime today;
  final DateTime lastDay;

  const _RepeatWeeklyDialog({required this.today, required this.lastDay});

  @override
  State<_RepeatWeeklyDialog> createState() => _RepeatWeeklyDialogState();
}

class _RepeatWeeklyDialogState extends State<_RepeatWeeklyDialog> {
  static const _weekdays = [
    (DateTime.monday, 'Mon'),
    (DateTime.tuesday, 'Tue'),
    (DateTime.wednesday, 'Wed'),
    (DateTime.thursday, 'Thu'),
    (DateTime.friday, 'Fri'),
    (DateTime.saturday, 'Sat'),
    (DateTime.sunday, 'Sun'),
  ];
  static const _periods = [
    (2, '2 weeks'),
    (4, '1 month'),
    (8, '2 months'),
    (13, '3 months'),
  ];

  final _selected = <int>{};
  int _weeks = 4;

  List<String> get _dates {
    final requestedEnd = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day + _weeks * 7 - 1,
    );
    return weeklyDates(
      from: widget.today,
      until: requestedEnd.isAfter(widget.lastDay)
          ? widget.lastDay
          : requestedEnd,
      weekdays: _selected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dates = _dates;
    return AlertDialog(
      title: const Text('Repeat Weekly'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Open every:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (day, label) in _weekdays)
                  FilterChip(
                    label: Text(label),
                    selected: _selected.contains(day),
                    onSelected: (on) => setState(
                      () => on ? _selected.add(day) : _selected.remove(day),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Starting today, for:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _weeks,
              isExpanded: true,
              items: [
                for (final (weeks, label) in _periods)
                  DropdownMenuItem(value: weeks, child: Text(label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _weeks = value);
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selected.isEmpty
                  ? 'Pick at least one day.'
                  : 'This opens ${dates.length} '
                        '${dates.length == 1 ? 'day' : 'days'}.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: dates.isEmpty ? null : () => Navigator.pop(context, dates),
          child: const Text('Open Days'),
        ),
      ],
    );
  }
}
