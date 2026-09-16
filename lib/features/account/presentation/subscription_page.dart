import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(sessionProvider).premium;

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Subscription',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 40),
        children: premium ? _active(context) : _free(context),
      ),
    );
  }

  List<Widget> _active(BuildContext context) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            0,
            Insets.gutter,
            22,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.promo,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: AppColors.pink,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'ejioji Premium',
                      style: AppText.title3.copyWith(fontSize: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('₹600', style: AppText.largeTitle.copyWith(fontSize: 34)),
                const SizedBox(height: 2),
                Text(
                  'a month, billed ₹1,799 every three months',
                  style: AppText.footnote.copyWith(
                    fontSize: 13.5,
                    color: const Color(0xB8FFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionGroup(
          header: 'Details',
          children: [
            AppRow(label: 'Plan', value: '3 months'),
            AppRow(label: 'Renews', value: '8 October 2026'),
            AppRow(label: 'Paid with', value: 'Apple ID', last: true),
          ],
        ),
        SectionGroup(
          footer: 'Subscriptions are managed by the store. Cancelling keeps '
              'Premium running until it renews, then the account goes back to '
              'free — nothing on your profile is lost.',
          children: [
            AppRow(
              label: 'Manage in the App Store',
              leading: const Icon(
                Icons.open_in_new,
                size: 18,
                color: AppColors.label2,
              ),
              onTap: () {},
            ),
            AppRow(
              label: 'Cancel subscription',
              destructive: true,
              last: true,
              leading: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.destructive,
              ),
              onTap: () {},
            ),
          ],
        ),
      ];

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
