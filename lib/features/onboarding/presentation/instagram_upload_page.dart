import 'dart:convert';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/instagram_download.dart';
import '../../../data/providers.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// Instagram, which has had no way in for a personal account since Basic
/// Display shut in December 2024.
///
/// So the person asks Instagram for their own download, and uploads it here.
/// The download is a zip of several hundred files with every direct message in
/// it, so the zip is opened on this phone and only what [InstagramDownload]
/// picks leaves it: their activity on other people's posts, and a summary of
/// their own messages worked out here (when, and the words and emoji they use
/// most), never a message. The server refuses any other file if one were sent.
class InstagramUploadPage extends ConsumerStatefulWidget {
  const InstagramUploadPage({this.editing = false, super.key});

  /// Opened from Edit tiles rather than setup; passed on to the reading screen.
  final bool editing;

  @override
  ConsumerState<InstagramUploadPage> createState() =>
      _InstagramUploadPageState();
}

class _InstagramUploadPageState extends ConsumerState<InstagramUploadPage> {
  bool _busy = false;

  /// Accounts Center's "Download your information". It asks the person to sign
  /// in if they are not, and lands on the page itself.
  static final _downloadPage = Uri.parse(
    'https://accountscenter.instagram.com/info_and_permissions/dyi/',
  );

  static const _steps = [
    (
      '1',
      'Open Download your information',
      'The button below goes straight there. Choose "Download or transfer '
          'information", then your Instagram account.',
    ),
    (
      '2',
      'Choose Some of your information',
      'Choose All available information. Your phone picks out what we read '
          'and leaves the rest, messages included, where it is.',
    ),
    (
      '3',
      'Download to device, in HTML',
      'Set the date range to Last year, the format to HTML (not JSON) and '
          'media quality to Low, then Create files.',
    ),
    (
      '4',
      'Come back with the zip',
      'Instagram lets you know when it is ready, usually within a few hours. '
          'Download the zip to your phone and choose it below.',
    ),
  ];

  Future<void> _openDownloadPage() async {
    final opened = await launchUrl(
      _downloadPage,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showAppToast(context, 'No browser would open Instagram.');
    }
  }

  /// What leaves the phone, read out of the zip at [path] off the main
  /// thread: a year of messages is a lot of HTML to go through.
  static Future<Map<String, Object>> _extract(String path) =>
      Isolate.run(() => InstagramDownload.read(path));

  /// Sends [body], asking once for the current notice if the server says the
  /// one agreed to does not cover it (the five-file notice of 2026-10-10).
  Future<String> _upload(String body) async {
    final sources = ref.read(sourcesRepositoryProvider);
    try {
      return (await sources.uploadInstagram(body)).id;
    } on ApiException catch (e) {
      if (e.code != 'notice_out_of_date') rethrow;
      await ref
          .read(consentRepositoryProvider)
          .grantCurrent(ConsentPurpose.instagramUpload);
      return (await sources.uploadInstagram(body)).id;
    }
  }

  /// Whether the zip is the JSON download rather than the HTML one.
  static bool _isJsonDownload(String path) {
    final input = InputFileStream(path);
    try {
      return ZipDecoder()
          .decodeStream(input)
          .files
          .any((f) => f.name.endsWith('likes/liked_posts.json'));
    } finally {
      input.closeSync();
    }
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      final path = picked?.files.singleOrNull?.path;
      if (path == null) return;

      final Map<String, Object> files;
      try {
        files = await _extract(path);
      } on Object {
        if (mounted) showAppToast(context, 'That file is not a zip we can open.');
        return;
      }
      if (files.isEmpty) {
        if (!mounted) return;
        showAppToast(
          context,
          _isJsonDownload(path)
              ? 'That download is in JSON. Ask Instagram for HTML instead.'
              : 'That zip has none of the files we read. Check the steps above.',
        );
        return;
      }

      final runId = await _upload(jsonEncode(files));
      if (!mounted) return;

      ref
        ..invalidate(connectionsProvider)
        ..invalidate(candidatesProvider)
        ..invalidate(myProfileProvider);

      // The upload opens and finishes its run inside the request; the topics
      // of the accounts are worked out just after, so tiles follow shortly.
      context.pushReplacement(
        Routes.readingRun(runId, editing: widget.editing),
      );
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
        title: 'Instagram',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Choose the zip',
        busy: _busy,
        onPressed: _pick,
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const LargeTitle(
            'Instagram has no way to connect',
            subtitle: 'So you ask Instagram for your own download. It takes a '
                'few taps now and a short wait.',
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
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              16,
              Insets.gutter,
              0,
            ),
            child: SecondaryButton(
              label: 'Open Download your information',
              onPressed: _openDownloadPage,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: NoteCard(
              icon: Icons.lock_outline,
              text: 'Your phone opens the zip and sends us what you follow, '
                  'like, save, watch, comment on and search for, your own '
                  'posts and bio, and when you message. Your messages never '
                  'leave your phone: it counts the words and emoji you use '
                  'most, with names taken out. We never keep other people\'s '
                  'captions, and friends\' accounts count for nothing.',
            ),
          ),
        ],
      ),
    );
  }
}
