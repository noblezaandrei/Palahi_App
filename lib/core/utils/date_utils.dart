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
