import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  List<Widget> _active(PremiumStatus status) {
    final plan = status.plans
        .where((p) => p.key == status.plan)
        .map((p) => p.title)
        .firstOrNull;
    final ends = status.endsAt;
    return [
      SectionGroup(
        header: 'Current plan',
        footer: 'Premium is free for now. Nothing renews and nothing is '
            'charged: when it ends you are back on free, and anything '
            'Premium turned on, like stealth, turns off with it.',
        children: [
          const AppRow(label: 'Plan', value: 'Premium'),
          if (plan != null) AppRow(label: 'Length', value: plan),
          AppRow(
            label: 'Ends',
            value: ends == null ? '' : dayLabel(ends.toLocal()),
            last: true,
          ),
        ],
      ),
    ];
  }

  List<Widget> _free(BuildContext context) => [
        const SectionGroup(
          header: 'Current plan',
          footer: 'Everything the product is for works on free: anyone can '
              'write to you, you can write to anyone, and replying is '
              'optional.',
          children: [AppRow(label: 'Plan', value: 'Free', last: true)],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: PrimaryButton(
            label: "See what's in Premium",
            onPressed: () => context.push(Routes.premium),
          ),
        ),
      ];
}
