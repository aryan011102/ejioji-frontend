import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/connect_controller.dart';
import '../../../data/providers.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/consent.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// What the profile is actually made of, and the one screen that deals with it.
///
/// Four sources, and only four. The original design offered nine, including
/// several that have no way in at all: Instagram's basic display API is gone,
/// LinkedIn work history needs partner access nobody gets, and Apple Health's
/// terms forbid what we would do with it. Offering a connect button for those
/// is a promise the product cannot keep. The layout is the design's; the list
/// is what exists.
///
/// Every source is read exactly once, when it is connected. There is no
/// background sync: the access token lives in the server's memory for the
/// couple of minutes the read takes and is revoked when it finishes, so there
/// is never a stored credential to leak.
///
/// Onboarding and Edit tiles open this same screen. Nothing here shows tiles:
/// Next walks the categories, and a category the sources could not fill asks
/// its questions there instead. A connected row opens what can be done to it,
/// reading it again or disconnecting it.
class ConnectAccountsPage extends ConsumerStatefulWidget {
  const ConnectAccountsPage({this.editing = false, super.key});

  /// Opened from the profile rather than during setup: a back button, and Next
  /// walks the categories in edit mode, saving each one as it goes.
  final bool editing;

  @override
  ConsumerState<ConnectAccountsPage> createState() =>
      _ConnectAccountsPageState();
}

/// One source in the list, and the line it shows before it is connected.
typedef _Source = ({SourceProvider provider, String name, String note});

class _ConnectAccountsPageState extends ConsumerState<ConnectAccountsPage> {
  /// The design's groups, holding only the sources that exist. Spotify is an
  /// upload here rather than a sign-in, and says so.
  static const _groups = <(String, List<_Source>)>[
    (
      'Music',
      [
        (
          provider: SourceProvider.spotify,
          name: 'Spotify',
          note: 'Manual · the listening history you download',
        ),
      ],
    ),
    (
      'Watching',
      [
        (
          provider: SourceProvider.youtube,
          name: 'YouTube',
          note: 'Subscriptions and likes · no watch history',
        ),
      ],
    ),
    (
      'Email receipts',
      [
        (
          provider: SourceProvider.gmail,
          name: 'Gmail',
          note: 'Order receipts only · no other mail is read',
        ),
      ],
    ),
    (
      'No public API — add these yourself',
      [
        (
          provider: SourceProvider.netflix,
          name: 'Netflix',
          note: 'Manual · no public API since 2014',
        ),
      ],
    ),
  ];

  static final _sourceCount = _groups.fold(0, (n, g) => n + g.$2.length);

  /// A read again or a disconnect in progress. Connecting has its own state in
  /// [connectProvider].
  SourceProvider? _busy;

  void _refetch() {
    ref
      ..invalidate(connectionsProvider)
      ..invalidate(candidatesProvider)
      ..invalidate(myProfileProvider)
      ..invalidate(consentProvider);
  }

  Future<void> _connect(SourceProvider provider, ConsentState consent) async {
    // Consent first, always. The server refuses to authorize a source whose
    // purpose is not open, so asking here is not a courtesy: it is the only
    // order that works.
    if (!consent.canConnect(provider)) {
      final granted = await context.push<bool>(
        '${Routes.consent}?purpose=${provider.purpose.wire}',
      );
      if (granted != true || !mounted) return;
    }
    await _read(provider, declined: 'No problem. Nothing was read.');
  }

  /// Reads a source: Google's screen for the two sign-ins, the file for the
  /// two uploads. Reading again is the same thing under a fresh permission,
  /// never a sync.
  Future<void> _read(SourceProvider provider, {String? declined}) async {
    switch (provider) {
      case SourceProvider.netflix:
        await context.push(Routes.netflixUpload);
        return;
      case SourceProvider.spotify:
        await context.push(Routes.spotifyUpload);
        return;
      default:
        break;
    }
    try {
      final run = await ref.read(connectProvider.notifier).begin(provider);
      if (!mounted) return;
      if (run == null) {
        // They said no on the provider's own screen. That is an answer, not a
        // failure, and it is not re-asked in this session.
        if (declined != null) showAppToast(context, declined);
        return;
      }
      await context.push(Routes.readingRun(run.id));
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// What a connected row opens.
  Future<void> _manage(SourceProvider provider, String name) async {
    final choice = await showAppActionSheet(
      context,
      title: '$name · connected',
      message: 'Disconnecting deletes everything we derived from it, not just '
          'the link.',
      actions: const [
        SheetAction('What we read', icon: Icons.visibility_outlined),
        SheetAction('Refresh data', icon: Icons.refresh),
        SheetAction(
          'Disconnect',
          icon: Icons.remove_circle_outline,
          destructive: true,
        ),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 0:
        await context.push(
          '${Routes.consent}?purpose=${provider.purpose.wire}',
        );
      case 1:
        setState(() => _busy = provider);
        try {
          await _read(provider);
        } finally {
          if (mounted) setState(() => _busy = null);
        }
      case 2:
        await _disconnect(provider, name);
    }
  }

  /// Disconnecting withdraws the permission, and the server deletes what that
  /// source produced in the same step: its records, its tiles, and those
  /// tiles' places on the profile.
  Future<void> _disconnect(SourceProvider provider, String name) async {
    setState(() => _busy = provider);
    try {
      await ref.read(consentRepositoryProvider).revoke(provider.purpose);
      if (!mounted) return;
      _refetch();
      showAppToast(context, '$name is disconnected.');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _next() => context.push(
        widget.editing ? Routes.editCategoryAt(0) : Routes.pickCategoryAt(0),
      );

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(consentProvider);
    final connections = ref.watch(connectionsProvider);
    final connecting = ref.watch(connectProvider);

    final linked = <SourceProvider, Connection>{
      for (final c in connections.valueOrNull ?? const <Connection>[])
        if (c.isActive) c.provider: c,
    };
    final locked = connecting != null || _busy != null || !consent.hasValue;

    return AppScaffold(
      navBar: widget.editing
          ? AppNavBar(backLabel: 'Profile', onBack: () => context.pop())
          : null,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: 'Next',
            // In edit mode there is always something to walk: answers stand
            // in for a category nothing filled.
            onPressed: widget.editing || linked.isNotEmpty ? _next : null,
          ),
          // Nothing connected still has a way on: every category comes back
          // thin, so the walk is all questions.
          if (!widget.editing && linked.isEmpty)
            TextActionButton(
              label: "I'll do this later",
              dim: true,
              onPressed: _next,
            ),
        ],
      ),
      child: connections.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: _refetch),
        data: (_) => ListView(
          padding: EdgeInsets.only(top: widget.editing ? 0 : 12, bottom: 22),
          children: [
            const _Heading(),
            _ReadOnceCard(onTap: () => context.push(Routes.consent)),
            _StrengthCard(linked: linked, of: _sourceCount),
            for (final (header, sources) in _groups)
              _Group(
                header: header,
                children: [
                  for (final s in sources)
                    _SourceRow(
                      source: s,
                      connection: linked[s.provider],
                      busy: connecting == s.provider || _busy == s.provider,
                      last: s == sources.last,
                      onTap: locked
                          ? null
                          : linked.containsKey(s.provider)
                              ? () => _manage(s.provider, s.name)
                              : () => _connect(
                                    s.provider,
                                    consent.requireValue,
                                  ),
                    ),
                ],
              ),
            if (!widget.editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.titleGutter,
                  18,
                  Insets.titleGutter,
                  0,
                ),
                child: Text(
                  'You can add, refresh or remove any source later from Edit '
                  'tiles on your profile.',
                  style: AppText.caption.copyWith(height: 17 / 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.titleGutter,
        4,
        Insets.titleGutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Complete your profile', style: AppText.largeTitle),
          const SizedBox(height: 6),
          Text(
            'We match on how you actually live, so we read it from what you '
            'already use — not from a form about yourself. Connect whatever '
            'you are comfortable with.',
            style: AppText.callout.copyWith(height: 20 / 15),
          ),
        ],
      ),
    );
  }
}

/// The promise, in one card, with the full notices behind it.
class _ReadOnceCard extends StatelessWidget {
  const _ReadOnceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppText.caption.copyWith(
      fontSize: 12.5,
      height: 17 / 12.5,
      color: AppColors.label2,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 16, Insets.gutter, 0),
      child: Pressable(
        onTap: onTap,
        semanticLabel: 'What we read',
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: _panel,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.lock, size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      const TextSpan(text: 'Each account is read '),
                      TextSpan(
                        text: 'once',
                        style: style.copyWith(
                          color: AppColors.label,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: ', then disconnected. We keep the taste we '
                            'derive, never your messages, and we can never '
                            'post as you. ',
                      ),
                      TextSpan(
                        text: 'What we read',
                        style: style.copyWith(color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.label3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How much there is to match on: a word, six segments and a line.
///
/// It counts connected sources, since that is what this screen changes. With
/// four sources the segments go 0, 2, 3, 5, 6, so each source visibly moves
/// the bar and the last one fills it.
class _StrengthCard extends StatelessWidget {
  const _StrengthCard({required this.linked, required this.of});

  final Map<SourceProvider, Connection> linked;
  final int of;

  static const _segments = 6;

  @override
  Widget build(BuildContext context) {
    final n = linked.length;
    final filled = (n * _segments / math.max(of, 1)).round();
    final (word, line) = switch (n) {
      0 => ('Empty', 'Nothing connected yet.'),
      1 => (
          'Thin',
          'A start. Music and watching sharpen taste matching the most.',
        ),
      _ when n < of => (
          'Good',
          linked.containsKey(SourceProvider.gmail)
              ? 'Enough to match on.'
              : 'Enough to match on. Receipts add how you actually spend a '
                  'weekend.',
        ),
      _ => ('Strong', 'Everything from here only refines the edges.'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 20, Insets.gutter, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
        decoration: _panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile strength',
                    style: AppText.bodyStrong.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Text(
                  word,
                  style: AppText.footnote.copyWith(
                    fontWeight: FontWeight.w700,
                    color: n >= 2 ? AppColors.ok : AppColors.label2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                for (var i = 0; i < _segments; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < filled ? AppColors.fill : AppColors.fill3,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 9),
            Text(line, style: AppText.caption.copyWith(height: 16 / 12)),
          ],
        ),
      ),
    );
  }
}

/// A sentence-case header over one rounded plate of rows.
class _Group extends StatelessWidget {
  const _Group({required this.header, required this.children});

  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 26, Insets.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
            child: Text(header, style: AppText.footnote),
          ),
          DecoratedBox(
            decoration: _panel,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.panel),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.connection,
    required this.busy,
    required this.last,
    required this.onTap,
  });

  final _Source source;
  final Connection? connection;
  final bool busy;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = connection;
    final run = c?.latestRun;
    final problem = run?.problem;
    final reading = busy || (run?.isRunning ?? false);
    final done = c != null && !reading && problem == null;

    final (String line, Color tone) = switch (c) {
      null when busy => ('Connecting…', AppColors.label3),
      null => (source.note, AppColors.label3),
      _ when reading => ('Reading now…', AppColors.label3),
      _ when problem != null => (problem, AppColors.destructive),
      _ => _found(run),
    };

    return Column(
      children: [
        PressableRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                _BrandMark(source.provider),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: AppText.body.copyWith(
                          fontSize: 17,
                          height: 25.5 / 17,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        line,
                        style: AppText.caption.copyWith(
                          fontSize: 12.5,
                          height: 16 / 12.5,
                          color: tone,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (reading)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: AppColors.label3,
                    ),
                  )
                else if (done)
                  const Icon(Icons.check_circle, size: 21, color: AppColors.ok)
                else
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.label3,
                  ),
              ],
            ),
          ),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.separator,
            ),
          ),
      ],
    );
  }

  /// What a finished read found. Green when it found enough to say something,
  /// quiet when it did not, because a green "found 3" would overclaim.
  (String, Color) _found(IngestionRun? run) {
    if (run == null) return ('Connected', AppColors.ok);
    return switch (run.sufficiency) {
      Sufficiency.strong ||
      Sufficiency.moderate =>
        ('Read ${run.itemsFound} things', AppColors.ok),
      Sufficiency.weak => (
          'Only found ${run.itemsFound}. That may be too little to say much',
          AppColors.label3,
        ),
      _ => ('Nothing found here', AppColors.label3),
    };
  }
}

/// The 30pt square in each source's own colour.
class _BrandMark extends StatelessWidget {
  const _BrandMark(this.provider);

  final SourceProvider provider;

  @override
  Widget build(BuildContext context) {
    final (Color back, Widget mark) = switch (provider) {
      SourceProvider.spotify => (
          BrandColors.spotify,
          const CustomPaint(size: Size(20, 20), painter: _SpotifyWaves()),
        ),
      SourceProvider.youtube => (
          BrandColors.youtube,
          const Icon(
            Icons.play_arrow_rounded,
            size: 20,
            color: AppColors.label,
          ),
        ),
      SourceProvider.netflix => (
          BrandColors.netflix,
          Text(
            'N',
            style: AppText.title3.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              height: 1,
            ),
          ),
        ),
      SourceProvider.gmail => (
          BrandColors.gmail,
          const Icon(
            Icons.mail_rounded,
            size: 18,
            color: BrandColors.gmailRed,
          ),
        ),
      SourceProvider.unknown => (
          AppColors.fill2,
          const Icon(Icons.link, size: 18, color: AppColors.label2),
        ),
    };
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: back,
        borderRadius: BorderRadius.circular(8.4),
        border: Border.all(color: BrandColors.edge),
      ),
      alignment: Alignment.center,
      child: mark,
    );
  }
}

/// Spotify's three arcs, which no icon font carries.
class _SpotifyWaves extends CustomPainter {
  const _SpotifyWaves();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.label
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    for (final (y, span, stroke) in [
      (h * 0.36, 0.56, 1.9),
      (h * 0.52, 0.46, 1.7),
      (h * 0.67, 0.36, 1.5),
    ]) {
      paint.strokeWidth = stroke;
      final path = Path()
        ..moveTo(w * (0.5 - span / 2), y)
        ..quadraticBezierTo(
          w / 2,
          y - h * 0.12,
          w * (0.5 + span / 2),
          y + h * 0.03,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SpotifyWaves oldDelegate) => false;
}

/// The plate every card and group on this screen sits on.
final _panel = BoxDecoration(
  color: AppColors.row,
  borderRadius: BorderRadius.circular(Radii.panel),
  border: Border.all(color: AppColors.hairline),
);
