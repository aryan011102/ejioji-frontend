/// Formatting that is the client's business.
///
/// Anything the server computes is rendered as the server sent it: tile
/// numbers, currency and percentages are all formatted server-side, because a
/// client that groups digits its own way will eventually disagree with the
/// profile it is showing. What is left here is time, which is relative to the
/// reader's clock and so can only be done here.
library;

/// How long ago, in the shape a chat list wants.
///
/// Deliberately coarse. "3 minutes ago" and "4 minutes ago" say the same
/// thing, and a list of exact durations reads like a log file.
String relativeTime(DateTime at, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final gap = current.difference(at);

  if (gap.isNegative) return 'now';
  if (gap.inMinutes < 1) return 'now';
  if (gap.inMinutes < 60) return '${gap.inMinutes}m';

  // Calendar days, not 24-hour blocks: something at 11pm last night is
  // "Yesterday" at 9am, not "10h".
  //
  // This has to be decided before the hours branch. Checking `inHours < 24`
  // first makes the day comparison below unreachable for exactly the cases it
  // exists to handle.
  final days = _midnight(current).difference(_midnight(at)).inDays;
  if (days == 0) return '${gap.inHours}h';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '${days}d';
  if (days < 365) return '${days ~/ 7}w';
  return '${days ~/ 365}y';
}

/// The time of day, for a message bubble.
String clockTime(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${at.hour < 12 ? 'am' : 'pm'}';
}

/// The separator between days in a conversation.
String dayLabel(DateTime at, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final days = _midnight(current).difference(_midnight(at)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '${at.day} ${_months[at.month - 1]}'
      '${at.year == current.year ? '' : ' ${at.year}'}';
}

/// How long until something comes back, for a rationed allowance.
String timeUntil(DateTime at, {DateTime? now}) {
  final gap = at.difference(now ?? DateTime.now());
  if (gap.isNegative || gap.inMinutes < 1) return 'shortly';
  if (gap.inHours < 1) return 'in ${gap.inMinutes} minutes';
  if (gap.inHours == 1) return 'in an hour';
  return 'in ${gap.inHours} hours';
}

/// A span of months, for how far back something reaches: "Jan 2024 → today",
/// or "Mar 2025 → Aug 2026". An end within the last month reads "today",
/// because a receipt from three weeks ago means the inbox is current.
String monthSpan(DateTime from, DateTime to, {DateTime? now}) {
  final current = now ?? DateTime.now();
  String month(DateTime d) => '${_months[d.month - 1]} ${d.year}';
  final recent = current.difference(to).inDays <= 31;
  final end = recent ? 'today' : month(to);
  if (!recent && from.year == to.year && from.month == to.month) {
    return month(from);
  }
  return '${month(from)} → $end';
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

const _months = [
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
