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
