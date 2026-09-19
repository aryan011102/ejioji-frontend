import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// One conversation.
///
/// The families handshake lives in the ··· menu rather than as a card at the
/// top: a card standing over every thread asks a question the other person can
/// feel, and buried in the menu it is available without being posed.
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({required this.threadId, super.key});

  final String threadId;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

enum _Handshake { idle, waiting, both }

class _ConversationPageState extends ConsumerState<ConversationPage> {
  _Handshake _handshake = _Handshake.idle;
  bool _shareFriends = true;
  bool _shareFamily = true;
  final _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _menu() async {
    final label = switch (_handshake) {
      _Handshake.idle => 'Ready for friends and family',
      _Handshake.waiting => "You're ready · waiting on them",
      _Handshake.both => 'Open the shared pages',
    };

    final choice = await showAppActionSheet(
      context,
      message: '${Demo.themFirst} is never told about any of this, the first '
          'one included.',
      actions: [
        SheetAction(label, icon: Icons.people_alt_rounded),
        const SheetAction('Safety tips', icon: Icons.shield_outlined),
        const SheetAction('Report', destructive: true),
        const SheetAction('Block ${Demo.themFirst}', destructive: true),
      ],
    );
    if (choice == 0 && _handshake == _Handshake.idle && mounted) {
      await _shareSheet();
    }
  }

  Future<void> _shareSheet() async {
    await showAppSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconPlate(
                  Icons.people_alt_rounded,
                  size: 34,
                  radius: 10,
                  foreground: AppColors.accent,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready for friends and family',
                        style: AppText.title3.copyWith(fontSize: 18),
                      ),
                      Text(
                        'Private until you both are',
                        style: AppText.caption.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SectionGroup(
              children: [
                AppRow(
                  label: 'Friends',
                  subtitle: 'The profile exactly as it is — every tile, every '
                      'photo.',
                  control: AppSwitch(
                    value: _shareFriends,
                    onChanged: (v) => setSheetState(() => _shareFriends = v),
                  ),
                ),
                AppRow(
                  label: 'Family',
                  subtitle: 'The shorter one: the facts, and the habits summed '
                      'up.',
                  last: true,
                  control: AppSwitch(
                    value: _shareFamily,
                    onChanged: (v) => setSheetState(() => _shareFamily = v),
                  ),
                ),
              ],
            ),
            Text(
              'Nothing is shared until they turn theirs on too, and they are '
              'not told either way. Both links can be withdrawn.',
              style: AppText.caption,
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: "I'm ready",
              onPressed: _shareFriends || _shareFamily
                  ? () {
                      Navigator.of(sheetContext).pop();
                      setState(() => _handshake = _Handshake.both);
                      showAppToast(
                        context,
                        "You're ready. Nothing is shared until they are too.",
                      );
                    }
                  : null,
            ),
            Center(
              child: TextActionButton(
                label: 'Not yet',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: _header(context),
      footer: _composerBar(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 12, Insets.gutter, 16),
        children: [
          const NoteCard(
            icon: Icons.shield_outlined,
            text: 'Keep it in the app for now. Nobody from theonebytwo will ever ask '
                'for money, documents or an OTP. Report anyone who does.',
          ),
          const SizedBox(height: 12),
          if (_handshake == _Handshake.both) _readyCard(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Today', style: AppText.micro),
            ),
          ),
          for (final m in Demo.messages) _Bubble(message: m),
        ],
      ),
    );
  }

  PreferredSizeWidget _header(BuildContext context) => AppNavBar(
        title: Demo.themName,
        backLabel: 'Chats',
        onBack: () => context.pop(),
        trailingLabel: '···',
        onTrailing: _menu,
      );

  Widget _readyCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.fill2,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Both of you are ready', style: AppText.bodyStrong),
          const SizedBox(height: 3),
          Text(
            "These open ${Demo.themFirst}'s pages. Yours opened for him at the "
            'same moment. Either of you can withdraw, which stops all of them '
            '— and since there is no file to save, withdrawing really is the '
            'end of it.',
            style: AppText.caption.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          SectionGroup(
            children: [
              if (_shareFriends)
                AppRow(
                  label: 'For friends',
                  subtitle: 'Everything on his profile — open it',
                  last: !_shareFamily,
                  onTap: () {},
                  control: const MiniButton(label: 'Copy', tone: MiniTone.quiet),
                ),
              if (_shareFamily)
                AppRow(
                  label: 'For family',
                  subtitle: 'The shorter version — open it',
                  last: true,
                  onTap: () {},
                  control: const MiniButton(label: 'Copy', tone: MiniTone.quiet),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _composerBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Icon(Icons.add_circle_outline, color: AppColors.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
            child: TextField(
              controller: _composer,
              maxLines: null,
              // Bounded so a paste cannot push an unbounded payload at the API.
              maxLength: 2000,
              style: AppText.body.copyWith(fontSize: 15.5),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Message',
                hintStyle: AppText.body.copyWith(color: AppColors.label3),
                filled: true,
                fillColor: AppColors.row,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (_composer.text.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 9),
            child: Icon(Icons.mic, color: AppColors.accent, size: 20),
          )
        else
          Pressable(
            onTap: () => setState(_composer.clear),
            semanticLabel: 'Send',
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.fill,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward,
                size: 20,
                color: AppColors.onAccent,
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final DemoMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? AppColors.fill : AppColors.bubbleThem,
                    borderRadius: BorderRadius.circular(20),
                    border: mine
                        ? null
                        : Border.all(color: AppColors.bubbleThemEdge),
                  ),
                  child: Text(
                    message.text,
                    style: AppText.body.copyWith(
                      fontSize: 15.5,
                      height: 21 / 15.5,
                      color: mine ? AppColors.onAccent : AppColors.label,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // A read receipt only exists once a reply exists. Silence is
                  // an answer, not a status to report on.
                  message.mine && message.read
                      ? '${message.at} · Read'
                      : message.at,
                  style: AppText.micro.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
