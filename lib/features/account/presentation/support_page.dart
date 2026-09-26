import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

/// Support and privacy are one page on purpose: almost every support question
/// in this product is a privacy question wearing a different hat.
///
/// There is no "download or delete your data" row (Aryan's call, 2026-09-27).
/// Deleting the account is in Settings, and removing one app there deletes
/// what we worked out from it.
class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  static final _privacy = Uri.parse('https://theonebytwo.com/privacy');
  static final _terms = Uri.parse('https://theonebytwo.com/terms');

  /// The policies live on the website, so there is one copy of each. Opened
  /// in the browser, never a WebView.
  static Future<void> _open(BuildContext context, Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppToast(context, 'Could not open ${url.host}${url.path}.');
    }
  }

  static Widget _lead(IconData icon) =>
      Icon(icon, size: 18, color: AppColors.label2);

  static const _external = Icon(
    Icons.open_in_new,
    size: 15,
    color: AppColors.label4,
  );

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
              'theonebytwo builds a profile out of things you already did: '
              'orders, bookings, listening and watching. What follows says '
              'exactly what is read, what is shown, and what never is.',
              style: AppText.callout,
            ),
          ),
          SectionGroup(
            header: 'Your data',
            children: [
              AppRow(
                label: 'What we read from linked accounts',
                subtitle: 'Per app, in plain language',
                leading: _lead(Icons.description_outlined),
                onTap: () => context.push(Routes.supportRead),
              ),
              AppRow(
                label: 'What other people can see',
                leading: _lead(Icons.visibility_outlined),
                onTap: () => context.push(Routes.supportSeen),
              ),
              AppRow(
                label: 'What is never shown',
                subtitle: 'Spending, addresses, contacts',
                last: true,
                leading: _lead(Icons.visibility_off_outlined),
                onTap: () => context.push(Routes.supportNever),
              ),
            ],
          ),
          SectionGroup(
            header: 'Safety',
            children: [
              AppRow(
                label: 'Safety tips',
                leading: _lead(Icons.shield_outlined),
                onTap: () => context.push(Routes.safetyTips),
              ),
              AppRow(
                label: 'Report a problem',
                subtitle: 'Something broken, or an idea',
                last: true,
                leading: _lead(Icons.warning_amber_rounded),
                onTap: () => context.push(Routes.reportProblem),
              ),
            ],
          ),
          SectionGroup(
            header: 'The legal ones',
            footer:
                "Questions this page doesn't answer go to pritika@theonebytwo.com, "
                'which is a person.',
            children: [
              AppRow(
                label: 'Privacy policy',
                control: _external,
                onTap: () => _open(context, _privacy),
              ),
              AppRow(
                label: 'Terms of use',
                last: true,
                control: _external,
                onTap: () => _open(context, _terms),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
