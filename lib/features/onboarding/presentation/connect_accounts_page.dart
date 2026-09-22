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
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// What the profile is actually made of.
///
/// Four sources, and only four. The original design offered nine, including
/// several that have no way in at all: Instagram's basic display API is gone,
/// LinkedIn work history needs partner access nobody gets, and Apple Health's
/// terms forbid what we would do with it. Offering a connect button for those
/// is a promise the product cannot keep.
///
/// Every source is read exactly once, when it is connected. There is no
/// background sync: the access token lives in the server's memory for the
/// couple of minutes the read takes and is revoked when it finishes, so there
/// is never a stored credential to leak.
///
/// It is the only screen in onboarding that deals with sources. Nothing here
/// shows tiles: once something is connected, Next walks the categories, and a
/// category the sources could not fill asks its questions there instead.
///
/// [onboarding] is false when "Your insights" opens this to link one more app.
/// Then there is no walk to start, so the foot just goes back.
class ConnectAccountsPage extends ConsumerWidget {
  const ConnectAccountsPage({this.onboarding = true, super.key});

  final bool onboarding;

  static const _sources = <(SourceProvider, String, String)>[
    (
      SourceProvider.youtube,
      'YouTube',
      'The channels you follow and the videos you liked',
    ),
    (
      SourceProvider.gmail,
      'Gmail receipts',
      'Zomato and Swiggy food receipts, and Myntra delivery emails. No other '
          'mail is read',
    ),
    (
      SourceProvider.netflix,
      'Netflix',
      'The viewing file you download from your own profile',
    ),
    (
      SourceProvider.spotify,
      'Spotify',
      'The listening history you download from your own account',
    ),
  ];

  Future<void> _connect(
    BuildContext context,
    WidgetRef ref,
    SourceProvider provider,
    ConsentState consent,
  ) async {
    // Consent first, always. The server refuses to authorize a source whose
    // purpose is not open, so asking here is not a courtesy: it is the only
    // order that works.
    if (!consent.canConnect(provider)) {
      final granted = await context.push<bool>(
        '${Routes.consent}?purpose=${provider.purpose.wire}',
      );
      if (granted != true || !context.mounted) return;
    }

    if (provider == SourceProvider.netflix) {
      if (context.mounted) await context.push(Routes.netflixUpload);
      return;
    }

    if (provider == SourceProvider.spotify) {
      if (context.mounted) await context.push(Routes.spotifyUpload);
      return;
    }

    try {
      final run = await ref.read(connectProvider.notifier).begin(provider);
      if (!context.mounted) return;
      if (run == null) {
        // They said no on the provider's own screen. That is an answer, not a
        // failure, and it is not re-asked in this session.
        showAppToast(context, 'No problem. Nothing was read.');
        return;
      }
      context.push('${Routes.reading}?run=${run.id}');
    } on ApiException catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(consentProvider);
    final connections = ref.watch(connectionsProvider);
    final connecting = ref.watch(connectProvider);

    final linked = <SourceProvider, Connection>{
      for (final c in connections.valueOrNull ?? const <Connection>[])
        if (c.isActive) c.provider: c,
    };

    return AppScaffold(
      navBar: AppNavBar(backLabel: 'Back', onBack: () => context.pop()),
      footer: !onboarding
          ? PrimaryButton(label: 'Done', onPressed: () => context.pop())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(
                  label: 'Next',
                  onPressed: linked.isEmpty
                      ? null
                      : () => context.push(Routes.pickCategoryAt(0)),
                ),
                // Nothing connected still has a way on: every category comes
                // back thin, so the walk is all questions.
                if (linked.isEmpty)
                  TextActionButton(
                    label: "I'll do this later",
                    dim: true,
                    onPressed: () => context.push(Routes.pickCategoryAt(0)),
                  ),
              ],
            ),
      child: connections.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(connectionsProvider),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const LargeTitle(
              'Build your profile',
              subtitle: 'Connect what you use. We read the pattern, never the '
                  'contents: no messages, no addresses, no card numbers.',
            ),
            SectionGroup(
              children: [
                for (final (provider, name, note) in _sources)
                  AppRow(
                    label: name,
                    subtitle: linked[provider] == null
                        ? note
                        : _describe(linked[provider]!),
                    last: provider == _sources.last.$1,
                    control: MiniButton(
                      label: switch (provider) {
                        _ when linked.containsKey(provider) => 'Read again',
                        SourceProvider.netflix ||
                        SourceProvider.spotify =>
                          'Upload',
                        _ => 'Connect',
                      },
                      tone: linked.containsKey(provider)
                          ? MiniTone.quiet
                          : MiniTone.filled,
                      busy: connecting == provider,
                      icon: linked.containsKey(provider)
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.ok,
                            )
                          : null,
                      onPressed: connecting != null ||
                              !consent.hasValue
                          ? null
                          : () => _connect(
                                context,
                                ref,
                                provider,
                                consent.requireValue,
                              ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.titleGutter,
              ),
              child: Text(
                'Each source is read once, now. We do not keep the key '
                'afterwards, so reading again means asking you again. You can '
                'disconnect any of them later, and doing so deletes what it '
                'produced.',
                style: AppText.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What a finished read found, or why it did not finish.
  String _describe(Connection connection) {
    final run = connection.latestRun;
    if (run == null) return 'Connected';
    if (run.isRunning) return 'Reading now';

    final problem = run.problem;
    if (problem != null) return problem;

    return switch (run.sufficiency) {
      Sufficiency.strong || Sufficiency.moderate =>
        'Read ${run.itemsFound} things',
      Sufficiency.weak =>
        'Only found ${run.itemsFound}. That may be too little to say much',
      _ => 'Nothing found here',
    };
  }
}
