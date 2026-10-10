import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/models/consent.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

/// The AI question, put to everyone once (2026-09-30).
///
/// Sending summaries to Anthropic is sharing with a third-party AI, which Apple
/// requires an explicit yes for (guideline 5.1.2(i)) and which DPDP already
/// did. Before this, the question sat behind an optional card and in Settings,
/// so almost nobody was ever asked.
///
/// Asked when setup reaches the connect screen, before anything is read, so a
/// yes is in place when the first source's insights are proposed. Anyone who
/// got past setup without it (everyone signed up before this existed) is asked
/// once when the app opens instead. Never asked again after an answer: a grant
/// on record, or ever withdrawn, is an answer the server holds, and "Not now"
/// is remembered on this phone. Settings, Privacy choices, can change it at
/// any time either way.
Future<void> askAboutAiOnce(BuildContext context, WidgetRef ref) async {
  final userId = ref.read(sessionProvider).userId;
  if (userId == null || !_askedThisRun.add(userId)) return;
  final key = 'ai_consent_asked:$userId';

  final ConsentState state;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return;
    state = await ref.read(consentProvider.future);
  } on Object {
    // Nothing to ask with. The next launch tries again.
    _askedThisRun.remove(userId);
    return;
  }
  // Answered before, yes or later withdrawn: the server has it.
  if (state.grants.any((g) => g.purpose == ConsentPurpose.aiProcessing)) return;
  final notice = state.noticeFor(ConsentPurpose.aiProcessing);
  if (notice == null || !context.mounted) return;

  final allowed = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => AiConsentCard(
      onAllow: () => Navigator.of(sheetContext).pop(true),
      onNotNow: () => Navigator.of(sheetContext).pop(false),
      onReadNotice: () => _showNotice(sheetContext, notice),
    ),
  );

  if (allowed == true) {
    try {
      await ref
          .read(consentRepositoryProvider)
          .grant({ConsentPurpose.aiProcessing: notice.version});
      ref.invalidate(consentProvider);
    } on ApiException catch (e) {
      // Not remembered as asked, so it comes back next time rather than
      // leaving a yes that never reached the server.
      _askedThisRun.remove(userId);
      if (context.mounted) showAppToast(context, e.message);
      return;
    }
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  } on Object {
    // Without storage it may ask again on the next launch. Better than never.
  }
}

/// This run already asked this person, so two screens opening together ask
/// once, even before the phone's storage has answered.
final _askedThisRun = <String>{};

/// The same question, asked because they chose to: from "Who your data thinks
/// you are", where allowing AI is what gets archetypes written from their data.
/// Also how someone who said yes to an older notice agrees to the current one,
/// which covers archetypes. Returns true once the yes has reached the server.
Future<bool> askForAi(BuildContext context, WidgetRef ref) async {
  final ConsentNotice? notice;
  try {
    notice = (await ref.read(consentProvider.future))
        .noticeFor(ConsentPurpose.aiProcessing);
  } on ApiException catch (e) {
    if (context.mounted) showAppToast(context, e.message);
    return false;
  }
  if (notice == null || !context.mounted) return false;
  final allowed = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => AiConsentCard(
      onAllow: () => Navigator.of(sheetContext).pop(true),
      onNotNow: () => Navigator.of(sheetContext).pop(false),
      onReadNotice: () => _showNotice(sheetContext, notice!),
    ),
  );
  if (allowed != true) return false;
  try {
    await ref
        .read(consentRepositoryProvider)
        .grant({ConsentPurpose.aiProcessing: notice.version});
    ref.invalidate(consentProvider);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showAppToast(context, e.message);
    return false;
  }
}

Future<void> _showNotice(BuildContext context, ConsentNotice notice) {
  return showAppSheet<void>(
    context,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(notice.purpose.label, style: AppText.title3),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Text(notice.body, style: AppText.callout),
            ),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}

class AiConsentCard extends StatelessWidget {
  const AiConsentCard({
    required this.onAllow,
    required this.onNotNow,
    required this.onReadNotice,
    super.key,
  });

  final VoidCallback onAllow;
  final VoidCallback onNotNow;
  final VoidCallback onReadNotice;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: IconPlate(
            Icons.auto_awesome,
            size: 44,
            radius: 13,
            background: AppColors.blueSoft,
            foreground: AppColors.blue,
          ),
        ),
        const SizedBox(height: 14),
        Text('Let an AI suggest your insights?', style: AppText.title3),
        const SizedBox(height: 8),
        Text(
          'We send summaries of what you connect to Claude, an AI made by '
          'Anthropic: totals, and the names behind them, like the channels, '
          'artists or restaurants you come back to. It suggests which insights '
          'to show, writes their captions, and writes the archetypes you '
          'choose "who your data thinks you are" from.',
          style: AppText.callout,
        ),
        const SizedBox(height: 8),
        Text(
          'It never gets your emails, messages, photos, name or number, and it '
          'never makes up a number: we count everything ourselves. Anthropic '
          'may not train on it.',
          style: AppText.caption,
        ),
        const SizedBox(height: 8),
        Text(
          'Saying no is fine. You still get the standard insights, and you can '
          'change this in Settings, under Privacy choices.',
          style: AppText.caption,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextActionButton(
            label: 'Read the full notice',
            onPressed: onReadNotice,
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Allow', onPressed: onAllow),
        const SizedBox(height: 4),
        Center(
          child: TextActionButton(
            label: 'Not now',
            dim: true,
            onPressed: onNotNow,
          ),
        ),
      ],
    );
  }
}
