import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing can be subscribed to yet, so only the free reading is rendered.
    // `_active` is kept for when billing exists.

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Subscription',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 40),
        children: _free(context),
      ),
    );
  }

  // The paid reading of this screen was written before there was any billing
  // to drive it, and nothing could reach it. It is in the first commit of this
  // repository if it is wanted back when Premium exists.

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
