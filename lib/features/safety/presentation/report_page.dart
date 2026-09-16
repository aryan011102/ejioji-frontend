import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';

/// The reasons, ordered by how badly they need actioning rather than by how
/// often they are picked.
///
/// The two that carry real harm sit at the top where a moderator must see them
/// first. "Something else" is last, because a list that opens with it never
/// gets read past it.
const _reasons = <(String, String, String?)>[
  (
    'fake',
    "Fake profile or someone else's photos",
    "Photos that belong to someone else, or details that don't add up.",
  ),
  (
    'money',
    'Asking for money',
    'Investments, emergencies, a story that ends with a UPI ID.',
  ),
  ('abuse', 'Harassment, threats or abuse', null),
  ('sexual', 'Sexual content or nudity', null),
  ('minor', 'They may be under 18', null),
  ('married', 'Married or in a relationship', null),
  ('other', 'Something else', null),
];

/// Reporting is the one flow where the person using it is upset, so it asks
/// for as little as it can: one tap to name the thing, one optional screen to
/// say more, and then it stops asking.
class ReportReasonPage extends ConsumerStatefulWidget {
  const ReportReasonPage({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<ReportReasonPage> createState() => _ReportReasonPageState();
}

class _ReportReasonPageState extends ConsumerState<ReportReasonPage> {
  String? _chosen;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Report ${Demo.themFirst}',
        backLabel: 'Cancel',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Continue',
        onPressed: _chosen == null
            ? null
            : () => context.push(Routes.reportDetailsFor(widget.userId)),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const LargeTitle(
            'What happened?',
            subtitle: 'Pick the closest one. ${Demo.themFirst} is never told '
                'you reported them.',
          ),
          SectionGroup(
            children: [
              for (final (id, label, hint) in _reasons)
                _ReasonRow(
                  label: label,
                  hint: hint,
                  selected: _chosen == id,
                  last: id == _reasons.last.$1,
                  onTap: () => setState(() => _chosen = id),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: NoteCard(
              icon: Icons.shield_outlined,
              text: 'Reports go to a person, not a filter. If something breaks '
                  'the rules we act on the account, not just this '
                  'conversation.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.last,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PressableRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.fill : null,
                      border: selected
                          ? null
                          : Border.all(color: AppColors.label4, width: 1.5),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.onAccent,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppText.body),
                      if (hint != null) ...[
                        const SizedBox(height: 2),
                        Text(hint!, style: AppText.caption),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(left: 48),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: AppColors.separator,
            ),
          ),
      ],
    );
  }
}

/// Everything here is optional except the block, which is on by default.
///
/// Someone who has just reported almost never wants to keep hearing from the
/// person — but it stays a switch, because reporting a friend's hacked account
/// is a real thing that happens.
class ReportDetailsPage extends ConsumerStatefulWidget {
  const ReportDetailsPage({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends ConsumerState<ReportDetailsPage> {
  bool _block = true;
  final _detail = TextEditingController();

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Anything else?',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Send report',
        // TODO(backend): POST Api.report with the reason, the optional note and
        // any evidence ids, plus whether to block. The report is immutable
        // once sent — there is no edit.
        onPressed: () => context.push(
          '${Routes.reportSentFor(widget.userId)}?blocked=$_block',
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.row,
                borderRadius: BorderRadius.circular(Radii.row),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  const IconPlate(
                    Icons.flag,
                    background: AppColors.warnSoft,
                    foreground: AppColors.destructive,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text('Asking for money', style: AppText.body),
                  ),
                  TextActionButton(
                    label: 'Change',
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
          _label('In your words · optional'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: TextField(
              controller: _detail,
              maxLines: 5,
              // Bounded: a report is read by a person, and an unbounded field
              // is an unbounded payload.
              maxLength: 1000,
              style: AppText.body.copyWith(fontSize: 15.5),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'What happened, in as much or as little detail as '
                    'you want.',
                hintStyle: AppText.body.copyWith(
                  fontSize: 15.5,
                  color: AppColors.label3,
                ),
                filled: true,
                fillColor: AppColors.row,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.row),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.row),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.row),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
              ),
            ),
          ),
          _label('Screenshots · optional'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  const Expanded(child: PhotoSlot()),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.titleGutter,
              8,
              Insets.titleGutter,
              22,
            ),
            child: Text(
              'We can already see this conversation. Screenshots help when '
              'something happened somewhere else.',
              style: AppText.caption,
            ),
          ),
          SectionGroup(
            children: [
              AppRow(
                label: 'Block ${Demo.themFirst} too',
                subtitle: 'They stop being able to find you or write to you.',
                last: true,
                leading: const Icon(
                  Icons.block,
                  size: 18,
                  color: AppColors.label2,
                ),
                control: AppSwitch(
                  value: _block,
                  onChanged: (v) => setState(() => _block = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.titleGutter,
          22,
          Insets.titleGutter,
          8,
        ),
        child: Text(text.toUpperCase(), style: AppText.groupHeader),
      );
}

/// A receipt, not a thank-you.
///
/// It says who reads it, when, and what the other person is told — which is
/// nothing, now or later.
class ReportSentPage extends ConsumerWidget {
  const ReportSentPage({required this.blocked, super.key});

  final bool blocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: const AppNavBar(),
      footer: Column(
        children: [
          PrimaryButton(
            label: 'Done',
            onPressed: () => context.go(Routes.chats),
          ),
          const SizedBox(height: 8),
          const SecondaryButton(label: 'Safety tips'),
        ],
      ),
      child: ResultScaffoldBody(
        mark: const ResultMark(icon: Icons.flag, size: 82),
        title: 'Report sent.',
        body: 'Someone will read it within 24 hours. ${Demo.themFirst} is not '
            'told, now or later, and nothing you wrote is shown to them.',
        note: blocked
            ? const NoteCard(
                icon: Icons.block,
                text: '${Demo.themFirst} is blocked. The chat has moved out of '
                    'your list, and they can no longer find you or write to '
                    'you.',
              )
            : null,
      ),
    );
  }
}
