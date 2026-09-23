import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../data/sharing_repository.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// "Ready for friends and family", from a conversation's menu.
///
/// Nothing leaves the app until both people have said they are ready. Then
/// either can send a link to the *other* person's profile, which opens as a
/// page in whatever browser it lands in: no app, no sign-in, no way to message
/// anyone. A link works for two days, and either person stops every link in
/// the match at once by taking their ready back.
class SharePage extends ConsumerStatefulWidget {
  const SharePage({required this.matchId, this.name, super.key});

  final String matchId;

  /// The other person's first name, for the copy.
  final String? name;

  @override
  ConsumerState<SharePage> createState() => _SharePageState();
}

class _SharePageState extends ConsumerState<SharePage> {
  ShareState? _state;
  Object? _error;
  bool _busy = false;

  String get _them => widget.name ?? 'them';

  SharingRepository get _repo => ref.read(sharingRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final state = await _repo.load(widget.matchId);
      if (mounted) setState(() => _state = state);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Runs one change, shows what the server says afterwards, and puts any
  /// refusal in a toast rather than on a blank screen.
  Future<void> _act(Future<ShareState?> Function() change) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = await change();
      if (mounted && state != null) setState(() => _state = state);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(ShareAudience audience) => _act(() async {
        final made = await _repo.makeLink(widget.matchId, audience);
        if (!mounted) return null;
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            text: "$_them's profile on theonebytwo. The link works for two "
                'days: ${made.url}',
            subject: '$_them on theonebytwo',
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
        // Whether or not it was sent, the link exists now and is listed.
        return _repo.load(widget.matchId);
      });

  Future<void> _takeBack() async {
    final choice = await showAppActionSheet(
      context,
      title: 'Stop sharing?',
      message: 'Every link in this chat stops working, yours and $_them\'s. '
          'You can say you are ready again later.',
      actions: const [SheetAction('Stop sharing', destructive: true)],
    );
    if (choice != 0) return;
    await _act(() => _repo.takeBack(widget.matchId));
  }

  Future<void> _switchOff(ShareLink link) => _act(() async {
        await _repo.switchOff(link.id);
        return _repo.load(widget.matchId);
      });

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Friends and family',
        backLabel: 'Chat',
        onBack: () => context.pop(),
      ),
      footer: state == null ? null : _footer(state),
      child: state == null
          ? (_error == null
              ? const LoadingView()
              : ErrorView(error: _error!, onRetry: _load))
          : _body(state),
    );
  }

  Widget _body(ShareState state) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        LargeTitle(
          'Share $_them with the people you trust',
          subtitle: 'Send your family or friends a link to $_them\'s profile, '
              'once you have both said you are ready.',
        ),
        SectionGroup(
          children: [
            AppRow(
              label: 'You',
              value: state.meReady ? 'Ready' : 'Not yet',
            ),
            AppRow(
              label: _them,
              value: state.themReady ? 'Ready' : 'Not yet',
              last: true,
            ),
          ],
        ),
        if (state.links.isNotEmpty)
          SectionGroup(
            header: 'Your links',
            children: [
              for (final (i, link) in state.links.indexed)
                AppRow(
                  label: link.audience == ShareAudience.family
                      ? 'For family'
                      : 'For friends',
                  subtitle: 'Stops working ${timeUntil(link.expiresAt)}',
                  last: i == state.links.length - 1,
                  control: TextActionButton(
                    label: 'Switch off',
                    destructive: true,
                    onPressed: _busy ? null : () => _switchOff(link),
                  ),
                ),
            ],
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: NoteCard(
            icon: Icons.lock_outline,
            text: 'Friends see the profile as it is here. Family see a few '
                'plain sentences and the answers in the person\'s own words. '
                'Neither has contact details or any way to message anyone. '
                'Nothing leaves the app until you have both said you are ready, '
                'and either of you can stop it.',
          ),
        ),
      ],
    );
  }

  Widget _footer(ShareState state) {
    if (!state.meReady) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: "I'm ready",
            busy: _busy,
            onPressed: () => _act(() => _repo.ready(widget.matchId)),
          ),
          const SizedBox(height: 10),
          Text(
            state.themReady
                ? '$_them is ready. Say so too and either of you can share.'
                : '$_them will need to say so too.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    if (!state.themReady) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Waiting for $_them to say they are ready.',
            style: AppText.footnote,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Take it back',
            onPressed: _busy ? null : _takeBack,
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          label: 'Share with family',
          icon: const Icon(Icons.family_restroom_rounded, size: 18),
          busy: _busy,
          onPressed: () => _share(ShareAudience.family),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Share with friends',
          icon: const Icon(Icons.people_alt_rounded, size: 18),
          onPressed: _busy ? null : () => _share(ShareAudience.friends),
        ),
        const SizedBox(height: 4),
        TextActionButton(
          label: 'Stop sharing',
          destructive: true,
          onPressed: _busy ? null : _takeBack,
        ),
      ],
    );
  }
}
