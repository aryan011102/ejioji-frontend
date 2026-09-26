import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../data/support_repository.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// "Report a problem": feedback about the app, read by the team on the admin
/// Feedback page.
///
/// A problem with a person is not this. That is a report, which blocks them
/// too, and it starts from their profile or the chat. The note at the bottom
/// says so, because someone upset about a person may well land here first.
class ReportProblemPage extends ConsumerStatefulWidget {
  const ReportProblemPage({super.key});

  @override
  ConsumerState<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends ConsumerState<ReportProblemPage> {
  /// The server's limit. The field stops here so nothing typed is refused.
  static const _max = 2000;

  final _message = TextEditingController();
  FeedbackTopic _topic = FeedbackTopic.bug;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Send lights up as soon as there is something to send.
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final version = await ref.read(appVersionProvider.future);
      await ref.read(supportRepositoryProvider).sendFeedback(
            topic: _topic,
            message: _message.text,
            appVersion: version,
          );
      if (!mounted) return;
      showAppToast(context, 'Sent. Thank you for telling us.');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.row),
      borderSide: const BorderSide(color: AppColors.hairline),
    );
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Report a problem',
        backLabel: 'Support',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Send',
        busy: _sending,
        onPressed: _message.text.trim().isEmpty ? null : _send,
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const LargeTitle(
            'Tell us what happened',
            subtitle: 'Something broken, something confusing, or an idea. '
                'A person on the team reads every one.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in FeedbackTopic.values)
                  AppChip(
                    label: t.label,
                    selected: _topic == t,
                    onTap: () => setState(() => _topic = t),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: TextField(
              controller: _message,
              minLines: 6,
              maxLines: 12,
              maxLength: _max,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body.copyWith(fontSize: 15.5),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                hintText: switch (_topic) {
                  FeedbackTopic.bug =>
                    'What were you doing, and what went wrong?',
                  FeedbackTopic.idea => 'What would make theonebytwo better?',
                  FeedbackTopic.other => 'Whatever is on your mind.',
                },
                hintStyle: AppText.body.copyWith(
                  fontSize: 15.5,
                  color: AppColors.label3,
                ),
                counterStyle: AppText.micro,
                filled: true,
                fillColor: AppColors.row,
                contentPadding: const EdgeInsets.all(14),
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: NoteCard(
              icon: Icons.shield_outlined,
              text: 'A problem with a person? Report them from their profile or '
                  'your chat instead. That also blocks them, and they are '
                  'never told who reported them.',
            ),
          ),
        ],
      ),
    );
  }
}
