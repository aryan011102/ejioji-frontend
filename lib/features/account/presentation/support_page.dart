import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
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
          SectionGroup(
            header: 'The data ones',
            children: [
              AppRow(
                label: 'What we read from linked accounts',
                last: true,
                leading: _lead(Icons.description_outlined),
                onTap: () => context.push(Routes.supportRead),
              ),
            ],
          ),
          SectionGroup(
            header: 'The safety ones',
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
