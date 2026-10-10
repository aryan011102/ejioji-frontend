import 'dart:convert';

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
import '../../../data/providers.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// Instagram, which has had no way in for a personal account since Basic
/// Display shut in December 2024.
///
/// So the person asks Instagram for their own download, and uploads it here.
/// The download is a zip of several hundred files with every direct message in
/// it, so the zip is opened on this phone and only five files leave it: who
/// they follow, what they liked and saved, and the reels and posts they looked
/// at. Messages, photos, comments, searches and logins never leave the phone,
/// and the server refuses any other file if one were sent.
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

  /// The five files read, by the name the server knows them as, and where each
  /// sits in the zip. Matched on the end of the path: the zip may wrap them in
  /// a folder of its own.
  static const _files = {
    'following': 'connections/followers_and_following/following.html',
    'liked_posts': 'your_instagram_activity/likes/liked_posts.html',
    'saved_posts': 'your_instagram_activity/saved/saved_posts.html',
    'videos_watched': 'ads_information/ads_and_topics/videos_watched.html',
    'posts_viewed': 'ads_information/ads_and_topics/posts_viewed.html',
  };

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
      'Tick Followers and following, Likes, Saved, and Ads information. '
          'Nothing else is needed, and a smaller download arrives sooner.',
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

  /// The five files, read out of the zip at [path], as text. Nothing else in
  /// the zip is decompressed, let alone read.
  static Map<String, String> _extract(String path) {
    final input = InputFileStream(path);
    try {
      final zip = ZipDecoder().decodeStream(input);
      final found = <String, String>{};
      for (final entry in zip.files) {
        if (!entry.isFile) continue;
        final name = entry.name.replaceAll(r'\', '/');
        for (final MapEntry(key: key, value: suffix) in _files.entries) {
          if (name == suffix || name.endsWith('/$suffix')) {
            found[key] = utf8.decode(entry.content, allowMalformed: true);
          }
        }
      }
      return found;
    } finally {
      input.closeSync();
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

      final Map<String, String> files;
      try {
        files = _extract(path);
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

      final run = await ref
          .read(sourcesRepositoryProvider)
          .uploadInstagram(jsonEncode(files));
      if (!mounted) return;

      ref
        ..invalidate(connectionsProvider)
        ..invalidate(candidatesProvider)
        ..invalidate(myProfileProvider);

      // The upload opens and finishes its run inside the request; the topics
      // of the accounts are worked out just after, so tiles follow shortly.
      context.pushReplacement(
        Routes.readingRun(run.id, editing: widget.editing),
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
              text: 'Your phone opens the zip and sends us five files: who you '
                  'follow, what you liked and saved, and what you watched. '
                  'Your messages, photos, comments and searches never leave '
                  'your phone. We keep whose post it was and when, never the '
                  'caption, and friends\' accounts count for nothing.',
            ),
          ),
        ],
      ),
    );
  }
}
