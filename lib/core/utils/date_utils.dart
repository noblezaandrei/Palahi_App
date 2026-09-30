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

/// Bookings are daytime only, in hourly slots from 8:00 AM up to and
/// including 5:00 PM. firestore.rules enforces the same slots on bookingTime.
const bookingOpenHour = 8;
const bookingCloseHour = 17;

/// Every bookable time, "08:00 AM" through "05:00 PM".
final List<String> bookingTimeSlots = [
  for (var hour = bookingOpenHour; hour <= bookingCloseHour; hour++)
    formatBookingTime(hour, 0),
];

/// A 24-hour [hour] and [minute] as a booking time like "08:30 AM" — the
/// format stored on bookings and read back by [timeSlotHasPassed].
String formatBookingTime(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final period = hour < 12 ? 'AM' : 'PM';
  return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
}

/// A booking time like "08:30 AM" as a 24-hour (hour, minute), or null if
/// it isn't in that format.
(int, int)? _parseBookingTime(String time) {
  final match = RegExp(r'^(\d{1,2}):(\d{2}) (AM|PM)$').firstMatch(time.trim());
  if (match == null) return null;
  var hour = int.parse(match[1]!) % 12;
  if (match[3] == 'PM') hour += 12;
  return (hour, int.parse(match[2]!));
}

/// The hourly slot a booking time falls in, e.g. "09:30 AM" -> "09:00 AM",
/// or null if it can't be read. Bookings made before hourly slots could be
/// at any minute; they still take up the slot they fall in.
String? bookingSlotOf(String time) {
  final parsed = _parseBookingTime(time);
  return parsed == null ? null : formatBookingTime(parsed.$1, 0);
}

/// Whether a booking time slot like "08:00 AM" on [date] has already
/// started, so it can't be booked any more.
bool timeSlotHasPassed(DateTime date, String slot, {DateTime? now}) {
  final parsed = _parseBookingTime(slot);
  if (parsed == null) return false;
  final start = DateTime(date.year, date.month, date.day, parsed.$1, parsed.$2);
  return !start.isAfter(now ?? DateTime.now());
}

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Tue", "Wed", ….
String weekdayShort(DateTime date) => _weekdayNames[date.weekday - 1];

/// "Oct", "Nov", ….
String monthShort(DateTime date) => _monthNames[date.month - 1];

/// "Tue, Oct 6".
String formatShortDate(DateTime date) =>
    '${weekdayShort(date)}, ${monthShort(date)} ${date.day}';

/// A stored booking time like "09:00 AM" as "9:00 AM", for display.
String displayBookingTime(String time) =>
    time.startsWith('0') ? time.substring(1) : time;

/// A booking's stored date and time ("2026-10-06", "09:00 AM") as
/// "Tue, Oct 6 · 9:00 AM", or the raw values if the date can't be read.
String formatBookingSchedule(String bookingDate, String bookingTime) {
  final date = DateTime.tryParse(bookingDate);
  final day = date == null ? bookingDate : formatShortDate(date);
  return '$day · ${displayBookingTime(bookingTime)}';
}

/// Whether a booking's scheduled time has already come, so a still-pending
/// request for it can no longer be accepted.
bool bookingTimeHasPassed(
  String bookingDate,
  String bookingTime, {
  DateTime? now,
}) {
  final date = DateTime.tryParse(bookingDate);
  return date != null && timeSlotHasPassed(date, bookingTime, now: now);
}

/// "3:07 PM", in the device's local time.
String formatClockTime(DateTime dateTime) {
  final d = dateTime.toLocal();
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '$hour:${d.minute.toString().padLeft(2, '0')} $period';
}

/// "Today", "Yesterday", "Tue, Oct 6", or "Tue, Oct 6, 2025" for another
/// year — for the day dividers in a chat.
String formatDayHeader(DateTime dateTime, {DateTime? now}) {
  final d = dateTime.toLocal();
  final today = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  if (day == todayDay) return 'Today';
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return 'Yesterday';
  }
  final label = formatShortDate(d);
  return d.year == today.year ? label : '$label, ${d.year}';
}
