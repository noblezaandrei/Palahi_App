const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "3:07 PM" for today, otherwise "Sep 24" — for chat lists, where the time
/// alone made an old conversation look like it happened today.
String formatChatTime(DateTime dateTime) {
  final d = dateTime.toLocal();
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '$hour:${d.minute.toString().padLeft(2, '0')} $period';
  }
  return '${_monthNames[d.month - 1]} ${d.day}';
}

/// "Sep 24, 2026 at 3:07 PM", in the device's local time.
String formatDateTime(DateTime dateTime) {
  final d = dateTime.toLocal();
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '${_monthNames[d.month - 1]} ${d.day}, ${d.year} at $hour:$minute $period';
}

/// "October 2026".
String formatMonthYear(DateTime date) {
  const fullMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${fullMonthNames[date.month - 1]} ${date.year}';
}

/// [date] as "yyyy-MM-dd", the format of availableDates and bookingDate.
String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// How far ahead a breeder can open dates for booking.
const availabilityWindowDays = 180;

/// Every day from [from] (inclusive) through [until] (inclusive) that falls
/// on one of [weekdays] (DateTime.monday … DateTime.sunday), as yyyy-MM-dd.
/// For the availability calendar's "Repeat weekly" shortcut.
List<String> weeklyDates({
  required DateTime from,
  required DateTime until,
  required Set<int> weekdays,
}) {
  final dates = <String>[];
  // Calendar-day steps (not Duration(days: 1)), so a DST change can't skip
  // or repeat a day.
  for (
    var d = DateTime(from.year, from.month, from.day);
    !d.isAfter(until);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (weekdays.contains(d.weekday)) dates.add(dateKey(d));
  }
  return dates;
}

/// Bookings are daytime only: from 8:00 AM up to and including 5:00 PM.
/// firestore.rules enforces the same window on bookingTime.
const bookingOpenHour = 8;
const bookingCloseHour = 17;

bool isWithinBookingHours(int hour, int minute) {
  final minutes = hour * 60 + minute;
  return minutes >= bookingOpenHour * 60 && minutes <= bookingCloseHour * 60;
}

/// A 24-hour [hour] and [minute] as a booking time like "08:30 AM" — the
/// format stored on bookings and read back by [timeSlotHasPassed].
String formatBookingTime(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final period = hour < 12 ? 'AM' : 'PM';
  return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
}

/// Whether a booking time slot like "08:00 AM" on [date] has already
/// started, so it can't be booked any more.
bool timeSlotHasPassed(DateTime date, String slot, {DateTime? now}) {
  final match = RegExp(r'^(\d{1,2}):(\d{2}) (AM|PM)$').firstMatch(slot.trim());
  if (match == null) return false;
  var hour = int.parse(match[1]!) % 12;
  if (match[3] == 'PM') hour += 12;
  final start = DateTime(
    date.year,
    date.month,
    date.day,
    hour,
    int.parse(match[2]!),
  );
  return !start.isAfter(now ?? DateTime.now());
}
