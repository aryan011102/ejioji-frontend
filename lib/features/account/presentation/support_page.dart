import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/layout.dart';

/// Support and privacy are one page on purpose: almost every support question
/// in this product is a privacy question wearing a different hat.
class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Support and privacy',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.titleGutter,
              0,
              Insets.titleGutter,
              20,
            ),
            child: Text(
              'theonebytwo builds a profile out of things you already did — '
              'receipts, listening, watching, moving. What follows says '
              'exactly what is read, what is shown, and how to get rid of all '
              'of it.',
              style: AppText.callout,
            ),
          ),
          SectionGroup(
            header: 'Your data',
            children: [
              AppRow(
                label: 'What we read from linked accounts',
                subtitle: 'Per app, in plain language',
                leading: const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () {},
              ),
              AppRow(
                label: 'What other people can see',
                leading: const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () {},
              ),
              AppRow(
                label: 'What is never shown',
                subtitle: 'Spending, addresses, contacts',
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () {},
              ),
              AppRow(
                label: 'Download or delete your data',
                last: true,
                leading: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () {},
              ),
            ],
          ),
          SectionGroup(
            header: 'Safety',
            children: [
              AppRow(
                label: 'Safety tips',
                leading: const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () {},
              ),
              AppRow(
                label: 'Report a problem',
                last: true,
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.label2,
                ),
                onTap: () {},
              ),
            ],
          ),
          const SectionGroup(
            header: 'The legal ones',
            footer: "Questions this page doesn't answer go to pritika@theonebytwo.com, "
                'which is a person.',
            children: [
              AppRow(label: 'Privacy policy'),
              AppRow(label: 'Terms of use', last: true),
            ],
          ),
        ],
      ),
    );
  }
}
