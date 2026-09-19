import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// Spotify, from the person's own data download.
///
/// Spotify's API caps apps like ours at five people for good, so, as with
/// Netflix, the person fetches their own file. The download is a zip of many
/// files; only the listening history is wanted. Account data has it as
/// StreamingHistory_music_0.json, _1.json and so on; Extended streaming history
/// as Streaming_History_Audio_*.json. Everything else in the zip (Userdata.json
/// holds an address and an email) is left behind here, and the server refuses
/// any element that is not a play in case something slips through.
class SpotifyUploadPage extends ConsumerStatefulWidget {
  const SpotifyUploadPage({super.key});

  @override
  ConsumerState<SpotifyUploadPage> createState() => _SpotifyUploadPageState();
}

class _SpotifyUploadPageState extends ConsumerState<SpotifyUploadPage> {
  bool _busy = false;

  /// The server's limit. A bigger body is refused before it is read, so the
  /// app says so instead of uploading 40 MB to be told no.
  static const _maxBytes = 32 * 1024 * 1024;

  static final _historyFile = RegExp(
    r'^(StreamingHistory_music_\d+|Streaming_History_Audio_.+)\.json$',
  );

  static const _steps = [
    (
      '1',
      'Ask Spotify for your data',
      'In Spotify, go to Account, then Privacy settings, then Download your '
          'data. Tick Account data. It usually arrives by email in about five '
          'days.',
    ),
    (
      '2',
      'Open the zip from the email',
      'On an iPhone, tap it in the Files app to unzip it into a folder.',
    ),
    (
      '3',
      'Choose the listening history files',
      'The ones named StreamingHistory_music_0.json, _1.json and so on. Pick '
          'all of them at once. Leave the other files where they are.',
    ),
  ];

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: true,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final history = picked.files.where((f) => _historyFile.hasMatch(f.name));
      final skipped = picked.files.length - history.length;
      if (history.isEmpty) {
        if (mounted) {
          showAppToast(
            context,
            'None of those is listening history. Look for files named '
            'StreamingHistory_music_0.json.',
          );
        }
        return;
      }

      // Joined here into one array, which is what the server takes. Read and
      // re-encoded rather than glued as text, so a file that is not a JSON
      // array is caught on the phone with a clear message.
      final plays = <Object?>[];
      for (final file in history) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
        if (decoded is! List) {
          if (mounted) {
            showAppToast(context, '${file.name} is not a listening history file.');
          }
          return;
        }
        plays.addAll(decoded);
      }

      final body = jsonEncode(plays);
      if (utf8.encode(body).length > _maxBytes) {
        if (mounted) {
          showAppToast(
            context,
            'That is more than we can take in one go. Choose fewer files, '
            'starting with the newest.',
          );
        }
        return;
      }

      final run = await ref.read(sourcesRepositoryProvider).uploadSpotify(body);
      if (!mounted) return;

      ref
        ..invalidate(connectionsProvider)
        ..invalidate(candidatesProvider)
        ..invalidate(myProfileProvider);

      if (skipped > 0) {
        showAppToast(
          context,
          'Left out $skipped ${skipped == 1 ? 'file' : 'files'} that '
          '${skipped == 1 ? 'was not' : 'were not'} listening history.',
        );
      }

      // Like Netflix, the run finishes inside the request.
      context.pushReplacement('${Routes.reading}?run=${run.id}');
    } on FormatException {
      if (mounted) {
        showAppToast(context, 'One of those files could not be read.');
      }
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
        title: 'Spotify',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Choose the files',
        busy: _busy,
        onPressed: _pick,
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const LargeTitle(
            'Spotify, from your own download',
            subtitle: 'Spotify lets only five people connect to an app like '
                'ours, so you fetch the file yourself. It takes a few days to '
                'arrive: ask for it now and come back.',
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: NoteCard(
              icon: Icons.lock_outline,
              text: 'We keep the artist, the song, when it played and for how '
                  'long. Podcasts, audiobooks and private sessions are left '
                  'out, and so are the device and location Spotify lists with '
                  'each play. Uploading again replaces what is there.',
            ),
          ),
        ],
      ),
    );
  }
}
