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
class ConnectAccountsPage extends ConsumerWidget {
  const ConnectAccountsPage({super.key});

  static const _sources = <(SourceProvider, String, String)>[
    (
      SourceProvider.youtube,
      'YouTube',
      'The channels you follow and the videos you liked',
    ),
    (
      SourceProvider.gmail,
      'Food orders',
      'Zomato and Swiggy receipts in Gmail. No other mail is read',
    ),
    (
      SourceProvider.netflix,
      'Netflix',
      'The viewing file you download from your own profile',
    ),
    (
      SourceProvider.spotify,
      'Spotify',
      'Not available: Spotify caps apps like ours at five people',
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
      footer: PrimaryButton(
        label: linked.isEmpty ? 'Skip for now' : 'Continue',
        onPressed: () => context.push(Routes.editSources),
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
                        SourceProvider.spotify => 'Soon',
                        _ when linked.containsKey(provider) => 'Read again',
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
                      // Spotify is shown because people ask for it, and
                      // disabled because its developer mode caps at five
                      // users and its extended quota is closed to us.
                      onPressed: provider == SourceProvider.spotify ||
                              connecting != null ||
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
