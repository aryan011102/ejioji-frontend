import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// Netflix, which has had no API since 2014.
///
/// So the person fetches their own file. The instructions matter more than
/// usual here, because there are two downloads on Netflix and only one of them
/// is acceptable: the per-profile viewing activity, which is theirs alone. The
/// full account download contains every profile on the account, which is other
/// people's viewing, and the server refuses it by looking at the column names
/// before it reads a single row.
class NetflixUploadPage extends ConsumerStatefulWidget {
  const NetflixUploadPage({super.key});

  @override
  ConsumerState<NetflixUploadPage> createState() => _NetflixUploadPageState();
}

class _NetflixUploadPageState extends ConsumerState<NetflixUploadPage> {
  bool _busy = false;

  /// Netflix redirects this through a sign-in carrying a `nextpage` back to
  /// the same path, so signing in lands on the viewing activity itself. The
  /// page is per profile, which is exactly the one file we will accept.
  static final _viewingActivity = Uri.parse('https://www.netflix.com/viewingactivity');

  Future<void> _openViewingActivity() async {
    final opened = await launchUrl(_viewingActivity, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showAppToast(context, 'No browser would open Netflix.');
    }
  }

  static const _steps = [
    (
      '1',
      'Open your viewing activity',
      'The button below goes straight there. Sign in with your own profile if '
          'it asks: the file is per profile, and we only want yours.',
    ),
    (
      '2',
      'Scroll down and press Download all',
      'That saves NetflixViewingHistory.csv. Do not use the full data '
          'download from Netflix support: it holds everyone on the account, '
          'and we will refuse it.',
    ),
  ];

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      final bytes = picked?.files.singleOrNull?.bytes;
      if (bytes == null) return;

      // Read as text here rather than posting the file: the server takes the
      // CSV as the request body, parses it in memory and never writes it
      // anywhere. Nothing about a small text file needs blob storage.
      final csv = utf8.decode(bytes, allowMalformed: true);

      final run = await ref.read(sourcesRepositoryProvider).uploadNetflix(csv);
      if (!mounted) return;

      ref
        ..invalidate(connectionsProvider)
        ..invalidate(candidatesProvider)
        ..invalidate(myProfileProvider);

      // The upload opens and finishes its run inside the request, so there is
      // nothing to poll: this goes straight to the result.
      context.pushReplacement('${Routes.reading}?run=${run.id}');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Netflix',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Choose the file',
        busy: _busy,
        onPressed: _pick,
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const LargeTitle(
            'Netflix has no way to connect',
            subtitle: 'So you fetch the file yourself. It takes a minute and '
                'it is the same file either way.',
          ),
          SectionGroup(
            children: [
              for (final (number, title, body) in _steps)
                AppRow(
                  label: title,
                  subtitle: body,
                  last: number == _steps.last.$1,
                  leading: Text(number, style: AppText.bodyStrong),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 16, Insets.gutter, 0),
            child: SecondaryButton(
              label: 'Open Netflix viewing activity',
              onPressed: _openViewingActivity,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: NoteCard(
              icon: Icons.lock_outline,
              text: 'We read the titles and the dates, work out what you watch '
                  'and when, and keep nothing else. Uploading again replaces '
                  'what is there rather than adding to it.',
            ),
          ),
        ],
      ),
    );
  }
}
