import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/sheets.dart';

/// Chat streaks: days in a row on which both people wrote.
///
/// The server decides everything (what counts as a day, when it breaks, which
/// milestone was reached, what the popup says). The app shows the count under
/// the name and pops up once per milestone of each streak on this phone. A
/// broken streak says nothing: it just stops showing.

/// The line under the name at the top of a conversation.
String streakLabel(Streak streak) => '🔥 ${streak.days} days in a row';

/// Shown this session already, so two events arriving together pop up once
/// even before the phone's storage has answered.
final _shownThisRun = <String>{};

/// Shows the milestone popup unless this phone has shown it for this streak.
/// Remembered on the phone only: a second phone shows it again, which is fine.
Future<void> celebrateStreakOnce(
  BuildContext context, {
  required String matchId,
  required Streak streak,
  String? name,
}) async {
  final key = streak.popupKey(matchId);
  final line = streak.line;
  if (key == null || line == null || !_shownThisRun.add(key)) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
  } on Object {
    // Without storage it may show again next time. Better than never.
  }
  if (!context.mounted) return;
  await showAppSheet<void>(
    context,
    builder: (context) => StreakCard(
      days: streak.milestone!,
      line: line,
      name: name,
      onDone: () => Navigator.of(context).pop(),
    ),
  );
}

class StreakCard extends StatelessWidget {
  const StreakCard({
    required this.days,
    required this.line,
    required this.onDone,
    this.name,
    super.key,
  });

  /// The milestone reached.
  final int days;

  /// What the server says about it, to both people.
  final String line;

  /// The other person's first name, when it is known.
  final String? name;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final who = name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        const Text(
          '🔥',
          style: TextStyle(fontSize: 44),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '$days',
          style: AppText.tileNumber(56).copyWith(color: AppColors.accent),
          textAlign: TextAlign.center,
        ),
        Text(
          who == null ? 'days in a row' : 'days in a row with $who',
          style: AppText.title3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(line, style: AppText.callout, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Keep it going', onPressed: onDone),
      ],
    );
  }
}
