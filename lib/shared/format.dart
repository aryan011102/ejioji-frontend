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
  if (gap.inHours < 24) return '${gap.inHours}h';

  // Calendar days, not 24-hour blocks: something at 11pm last night is
  // "yesterday" at 1am, not "2h".
  final days = _midnight(current).difference(_midnight(at)).inDays;
  if (days <= 1) return 'Yesterday';
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
