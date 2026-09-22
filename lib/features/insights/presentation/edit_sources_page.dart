import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/connect_controller.dart';
import '../../../data/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/tile.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';
import 'category_page.dart';

/// What "Edit insights" opens: the linking page, not a category.
///
/// Whether an app is connected and which tiles are on the wall are two
/// different questions, and the first is the reason people come: a category
/// that went quiet is an account that stopped. So refresh, unlink and link all
/// live here, and each app opens its own tiles from here.
class EditSourcesPage extends ConsumerStatefulWidget {
  const EditSourcesPage({super.key});

  @override
  ConsumerState<EditSourcesPage> createState() => _EditSourcesPageState();
}

class _EditSourcesPageState extends ConsumerState<EditSourcesPage> {
  static const _order = [
    SourceProvider.youtube,
    SourceProvider.spotify,
    SourceProvider.netflix,
    SourceProvider.gmail,
  ];

  SourceProvider? _busy;

  void _refetch() {
    ref
      ..invalidate(connectionsProvider)
      ..invalidate(candidatesProvider)
      ..invalidate(myProfileProvider)
      ..invalidate(consentProvider);
  }

  /// Reading again is a second one-time read under a fresh permission, never
  /// a sync. Google sources go back through Google's screen; the two uploads
  /// go back to their file.
  Future<void> _refresh(SourceProvider provider) async {
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
    setState(() => _busy = provider);
    try {
      final run = await ref.read(connectProvider.notifier).begin(provider);
      if (!mounted || run == null) return;
      await context.push('${Routes.reading}?run=${run.id}');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Unlinking withdraws the permission, and the server deletes what that
  /// source produced in the same step: its records, its tiles, and those
  /// tiles' places on the profile. The sheet says so, because the old copy
  /// here promised the opposite.
  Future<void> _unlink(SourceProvider provider) async {
    final choice = await showAppActionSheet(
      context,
      title: 'Unlink ${provider.label}?',
      message: 'Everything we read from it is deleted, and its tiles come off '
          'your profile. You can link it again later.',
      actions: const [SheetAction('Unlink', destructive: true)],
    );
    if (choice != 0 || !mounted) return;
    setState(() => _busy = provider);
    try {
      await ref.read(consentRepositoryProvider).revoke(provider.purpose);
      if (!mounted) return;
      _refetch();
      showAppToast(context, '${provider.label} is unlinked.');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(connectionsProvider);
    final candidates = ref.watch(candidatesProvider);
    final profile = ref.watch(myProfileProvider);
    final bank = ref.watch(promptBankProvider);

    final loading = [connections, candidates, profile, bank];
    final failed = loading.where((a) => a.hasError).firstOrNull;

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Your insights',
        backLabel: 'Profile',
        onBack: () => context.pop(),
      ),
      child: failed != null
          ? ErrorView(error: failed.error!, onRetry: _refetch)
          : loading.any((a) => !a.hasValue)
              ? const LoadingView()
              : _list(
                  connections.requireValue,
                  candidates.requireValue,
                  profile.requireValue.tiles,
                  pickableCategories(
                    candidates.requireValue,
                    bank.requireValue.answers,
                    bank.requireValue,
                  ),
                ),
    );
  }

  Widget _list(
    List<Connection> connections,
    List<Insight> candidates,
    List<ProfileTile> onProfile,
    List<TileCategory> categories,
  ) {
    final linked = <SourceProvider, Connection>{
      for (final c in connections)
        if (c.isActive) c.provider: c,
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const LargeTitle(
          'Where your profile comes from',
          subtitle: 'Read an app again, unlink it, or add one. Open any of them '
              'to change which tiles are on your profile.',
        ),
        for (final provider in _order)
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 10),
            child: _SourceCard(
              provider: provider,
              connection: linked[provider],
              onProfile: onProfile
                  .where((t) => t.insight?.providers.contains(provider) ?? false)
                  .length,
              busy: _busy == provider,
              onOpen: _opener(provider, candidates, categories),
              onRefresh: () => _refresh(provider),
              onUnlink: () => _unlink(provider),
              onLink: () => context.push(Routes.linkMore),
            ),
          ),
        if (categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, 10),
            child: SecondaryButton(
              label: 'All categories, answers included',
              onPressed: () => context.push(Routes.editCategoryAt(0)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.titleGutter),
          child: Text(
            'Unlinking deletes what we read from that app and takes its tiles '
            'off your profile. Tiles you leave off your profile still inform '
            'matching.',
            style: AppText.caption,
          ),
        ),
      ],
    );
  }

  /// A source opens the first category its tiles land in, and the category page
  /// then steps through the rest of that source's categories rather than
  /// stopping there. Gmail feeds four now (food delivery, going out, travel and
  /// moving), and until this it opened food delivery and had no way onward, so
  /// the other three were unreachable from here.
  VoidCallback? _opener(
    SourceProvider provider,
    List<Insight> candidates,
    List<TileCategory> categories,
  ) {
    final walk = categoriesOf(provider, candidates, categories);
    if (walk.isEmpty) return null;
    return () => context.push(Routes.editCategoryAt(0, source: provider));
  }
}

/// Two decks: what the app is doing and where its tiles are, then what you can
/// do to the app.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.provider,
    required this.connection,
    required this.onProfile,
    required this.busy,
    required this.onOpen,
    required this.onRefresh,
    required this.onUnlink,
    required this.onLink,
  });

  final SourceProvider provider;
  final Connection? connection;
  final int onProfile;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback onRefresh;
  final VoidCallback onUnlink;
  final VoidCallback onLink;

  bool get _linked => connection != null;

  String get _state {
    final c = connection;
    if (c == null) return 'Not linked. Nothing from this yet';
    final run = c.latestRun;
    if (run == null) return 'Linked';
    if (run.isRunning) return 'Reading now';
    final problem = run.problem;
    if (problem != null) return problem;
    final when = relativeTime(run.finishedAt ?? run.startedAt);
    return '$onProfile on your profile · read $when';
  }

  bool get _troubled => connection?.latestRun?.problem != null;

  @override
  Widget build(BuildContext context) {
    final glyph = switch (provider) {
      SourceProvider.youtube => '📺',
      SourceProvider.spotify => '🎧',
      SourceProvider.netflix => '🎬',
      SourceProvider.gmail => '🧾',
      SourceProvider.unknown => '•',
    };
    final upload =
        provider == SourceProvider.netflix || provider == SourceProvider.spotify;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.row,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: Column(
          children: [
            PressableRow(
              onTap: _linked ? onOpen : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.fill2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(glyph, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(provider.label, style: AppText.bodyStrong),
                          const SizedBox(height: 2),
                          Text(
                            _state,
                            style: AppText.caption.copyWith(
                              fontSize: 12.5,
                              color: _troubled
                                  ? AppColors.destructive
                                  : AppColors.label3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_linked && onOpen != null)
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.label4,
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Divider(height: 0.5, thickness: 0.5, color: AppColors.separator),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              child: !_linked
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: MiniButton(
                        label: 'Link ${provider.label}',
                        onPressed: onLink,
                      ),
                    )
                  : Row(
                      children: [
                        MiniButton(
                          label: busy
                              ? 'Working…'
                              : upload
                                  ? 'Upload again'
                                  : 'Read again',
                          tone: MiniTone.quiet,
                          icon: const Icon(
                            Icons.refresh,
                            size: 15,
                            color: AppColors.accent,
                          ),
                          onPressed: busy ? null : onRefresh,
                        ),
                        const SizedBox(width: 8),
                        MiniButton(
                          label: 'Unlink',
                          tone: MiniTone.destructive,
                          onPressed: busy ? null : onUnlink,
                        ),
                        const Spacer(),
                        if (onOpen != null)
                          Text(
                            'Open tiles',
                            style: AppText.caption.copyWith(
                              fontSize: 12.5,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
