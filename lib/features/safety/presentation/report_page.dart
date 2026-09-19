import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';

/// The reasons, ordered by how badly they need actioning rather than by how
/// often they are picked, each mapped onto the server's list.
///
/// "Married or in a relationship" has no reason of its own on the server, so
/// it goes as `other` with those words at the top of the note, where the
/// moderator reads first.
const _reasons = <(String, ReportReason, String, String?)>[
  (
    'fake',
    ReportReason.fakeProfile,
    "Fake profile or someone else's photos",
    "Photos that belong to someone else, or details that don't add up.",
  ),
  (
    'money',
    ReportReason.scam,
    'Asking for money',
    'Investments, emergencies, a story that ends with a UPI ID.',
  ),
  ('abuse', ReportReason.harassment, 'Harassment, threats or abuse', null),
  ('sexual', ReportReason.inappropriate, 'Sexual content or nudity', null),
  ('hate', ReportReason.hate, 'Hate speech', null),
  ('minor', ReportReason.underage, 'They may be under 18', null),
  ('married', ReportReason.other, 'Married or in a relationship', null),
  ('other', ReportReason.other, 'Something else', null),
];

(String, ReportReason, String, String?)? _reasonById(String? id) =>
    _reasons.where((r) => r.$1 == id).firstOrNull;

String _them(String? name) => name ?? 'this person';

Map<String, String> _carry({String? name, String? matchId}) => {
      if (name != null) 'name': name,
      if (matchId != null) 'match': matchId,
    };

/// Reporting is the one flow where the person using it is upset, so it asks
/// for as little as it can: one tap to name the thing, one optional screen to
/// say more, and then it stops asking.
class ReportReasonPage extends ConsumerStatefulWidget {
  const ReportReasonPage({
    required this.userId,
    this.name,
    this.matchId,
    super.key,
  });

  final String userId;
  final String? name;

  /// Set when the report starts from a conversation, so it can cite it.
  final String? matchId;

  @override
  ConsumerState<ReportReasonPage> createState() => _ReportReasonPageState();
}

class _ReportReasonPageState extends ConsumerState<ReportReasonPage> {
  String? _chosen;

  @override
  Widget build(BuildContext context) {
    final them = _them(widget.name);
    return AppScaffold(
      navBar: AppNavBar(
        title: widget.name == null ? 'Report' : 'Report ${widget.name}',
        backLabel: 'Cancel',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Continue',
        onPressed: _chosen == null
            ? null
            : () => context.push(
                  Uri(
                    path: Routes.reportDetailsFor(widget.userId),
                    queryParameters: {
                      'reason': _chosen!,
                      ..._carry(name: widget.name, matchId: widget.matchId),
                    },
                  ).toString(),
                ),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          LargeTitle(
            'What happened?',
            subtitle: 'Pick the closest one. ${them[0].toUpperCase()}'
                '${them.substring(1)} is never told you reported them.',
          ),
          SectionGroup(
            children: [
              for (final (id, _, label, hint) in _reasons)
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
                        ? const Icon(Icons.check, size: 14, color: AppColors.onAccent)
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
            child: Divider(height: 0.5, thickness: 0.5, color: AppColors.separator),
          ),
      ],
    );
  }
}

/// The optional note, then send.
///
/// A report always blocks (the server does both in one call), so there is no
/// switch for it: a switch that could be turned off would be a promise the
/// server does not keep.
class ReportDetailsPage extends ConsumerStatefulWidget {
  const ReportDetailsPage({
    required this.userId,
    required this.reason,
    this.name,
    this.matchId,
    super.key,
  });

  final String userId;

  /// The row's id from the first page (`fake`, `money`, ...).
  final String? reason;
  final String? name;
  final String? matchId;

  @override
  ConsumerState<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends ConsumerState<ReportDetailsPage> {
  final _detail = TextEditingController();
  bool _sending = false;

  /// How many of their latest messages a report from a conversation cites. A
  /// moderator sees each cited message with ten either side, and nothing else
  /// of the conversation, so a report that cites nothing shows them nothing.
  static const _cite = 5;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<List<String>> _citations() async {
    final matchId = widget.matchId;
    final me = ref.read(sessionProvider).userId;
    if (matchId == null || me == null) return const [];
    try {
      final page = await ref.read(chatRepositoryProvider).messages(matchId);
      final theirs = page.messages.where((m) => !m.mine(me)).toList();
      return [
        for (final m in theirs.skip(theirs.length > _cite ? theirs.length - _cite : 0))
          m.id,
      ];
    } on ApiException {
      // The report still goes without citations rather than not at all.
      return const [];
    }
  }

  Future<void> _send((String, ReportReason, String, String?) reason) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final typed = _detail.text.trim();
      final note = reason.$1 == 'married'
          ? [reason.$3, if (typed.isNotEmpty) typed].join('\n\n')
          : typed;
      await ref.read(trustRepositoryProvider).report(
            userId: widget.userId,
            reason: reason.$2,
            note: note.isEmpty ? null : note,
            messageIds: await _citations(),
          );
      if (!mounted) return;
      // The report blocked them, which ends a match and declines a request:
      // every list that could show them is stale.
      ref
        ..invalidate(conversationsProvider)
        ..invalidate(matchesProvider)
        ..invalidate(incomingRequestsProvider)
        ..invalidate(outgoingRequestsProvider)
        ..invalidate(blockedProvider);
      context.go(
        Uri(
          path: Routes.reportSentFor(widget.userId),
          queryParameters: _carry(name: widget.name),
        ).toString(),
      );
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reasonById(widget.reason);
    if (reason == null) {
      return AppScaffold(
        navBar: AppNavBar(backLabel: 'Back', onBack: () => context.pop()),
        child: const EmptyState(
          icon: Icons.flag_outlined,
          title: 'Pick a reason first',
          body: 'Go back and choose what happened.',
        ),
      );
    }

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Anything else?',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Send report',
        busy: _sending,
        onPressed: () => _send(reason),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  Expanded(child: Text(reason.$3, style: AppText.body)),
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
                border: _border,
                enabledBorder: _border,
                focusedBorder: _border,
              ),
            ),
          ),
          const SizedBox(height: 22),
          SectionGroup(
            children: [
              AppRow(
                label: 'Reporting also blocks ${_them(widget.name)}',
                subtitle: 'They stop being able to find you or write to you, '
                    'and any conversation between you closes.',
                last: true,
                leading: const Icon(Icons.block, size: 18, color: AppColors.label2),
              ),
            ],
          ),
          if (widget.matchId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.titleGutter,
                0,
                Insets.titleGutter,
                0,
              ),
              child: Text(
                'The moderator sees their last few messages to you, and what '
                'was said around them. Not the whole conversation.',
                style: AppText.caption,
              ),
            ),
        ],
      ),
    );
  }

  OutlineInputBorder get _border => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.row),
        borderSide: const BorderSide(color: AppColors.hairline),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(Insets.titleGutter, 22, Insets.titleGutter, 8),
        child: Text(text.toUpperCase(), style: AppText.groupHeader),
      );
}

/// A receipt, not a thank-you.
///
/// It says who reads it, when, and what the other person is told, which is
/// nothing, now or later.
class ReportSentPage extends ConsumerWidget {
  const ReportSentPage({this.name, super.key});

  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final them = _them(name);
    final capital = '${them[0].toUpperCase()}${them.substring(1)}';
    return AppScaffold(
      navBar: const AppNavBar(),
      footer: PrimaryButton(
        label: 'Done',
        onPressed: () => context.go(Routes.chats),
      ),
      child: ResultScaffoldBody(
        mark: const ResultMark(icon: Icons.flag, size: 82),
        title: 'Report sent.',
        body: 'Someone will read it within 24 hours. $capital is not told, now or '
            'later, and nothing you wrote is shown to them.',
        note: NoteCard(
          icon: Icons.block,
          text: '$capital is blocked. Any chat between you has closed, and they '
              'can no longer find you or write to you.',
        ),
      ),
    );
  }
}
