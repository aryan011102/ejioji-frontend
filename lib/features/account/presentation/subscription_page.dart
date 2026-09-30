import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/models/premium.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(premiumProvider);

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Subscription',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      child: premium.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(premiumProvider),
        ),
        data: (status) => ListView(
          padding: const EdgeInsets.only(top: 18, bottom: 40),
          children: status.active ? _active(status) : _free(context),
        ),
      ),
    );
  }

  static final _manage =
      Uri.parse('https://apps.apple.com/account/subscriptions');

  static const _afterwards = 'When it ends you are back on free, and anything '
      'onebytwo plus turned on, like stealth, turns off with it.';

  /// What the footer says depends on where the plan came from: a free plan
  /// and a pass just end, a subscription renews until it is cancelled in
  /// the App Store, which is the only place it can be.
  static String footer(PremiumStatus status) {
    if (!status.fromStore) {
      return 'This plan was free. Nothing renews and nothing is charged. '
          '$_afterwards';
    }
    if (status.current?.renews ?? false) {
      return 'Bought in the App Store. It renews on its own until you cancel '
          'it there, at least 24 hours before the date above. $_afterwards';
    }
    return 'Bought in the App Store, once. It does not renew. $_afterwards';
  }

  List<Widget> _active(PremiumStatus status) {
    final plan = status.current?.title;
    final ends = status.endsAt;
    final renews = status.fromStore && (status.current?.renews ?? false);
    return [
      SectionGroup(
        header: 'Current plan',
        footer: footer(status),
        children: [
          const AppRow(label: 'Plan', value: 'onebytwo plus'),
          if (plan != null) AppRow(label: 'Length', value: plan),
          AppRow(
            label: renews ? 'Renews' : 'Ends',
            value: ends == null ? '' : dayLabel(ends.toLocal()),
            last: !renews,
          ),
          if (renews)
            AppRow(
              label: 'Manage subscription',
              last: true,
              onTap: () => launchUrl(
                _manage,
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _free(BuildContext context) => [
        const SectionGroup(
          header: 'Current plan',
          children: [AppRow(label: 'Plan', value: 'Free', last: true)],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: PrimaryButton(
            label: "See what's in onebytwo plus",
            onPressed: () => context.push(Routes.premium),
          ),
        ),
      ];
}
