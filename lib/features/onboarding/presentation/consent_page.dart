import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/native/apple_music_kit.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/models/consent.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// Asking, before anything is read.
///
/// This screen exists because the server will not let a source be connected
/// without an open grant for its purpose, and it should exist anyway: consent
/// here is per purpose, versioned and revocable, not a single checkbox at
/// signup.
///
/// Two rules shape it:
///
/// - **The words are the server's.** The notice text lives in the backend
///   repository, is hash-locked once published, and the grant records the hash
///   the server computed. This screen renders that text; it never writes its
///   own summary of what someone is agreeing to, because then the audit trail
///   would record one wording and the person would have read another.
/// - **Refusing is a real answer.** Nothing here is pre-ticked, nothing is
///   required, and a person who grants none of it still has a route to a
///   profile through the questions.
class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({this.purposes, super.key});

  /// Which purposes to ask about. Null asks about all of them, which is the
  /// onboarding case; a single one is the "you need this to connect that"
  /// case.
  final List<ConsentPurpose>? purposes;

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  final _chosen = <ConsentPurpose>{};
  bool _saving = false;
  bool _seeded = false;

  /// The order they are asked in: the sources first, then the two that cut
  /// across all of them.
  static const _order = [
    ConsentPurpose.youtubeImport,
    ConsentPurpose.gmailReceipts,
    ConsentPurpose.netflixUpload,
    ConsentPurpose.spotifyImport,
    ConsentPurpose.appleMusicImport,
    ConsentPurpose.aiProcessing,
    ConsentPurpose.matching,
  ];

  /// Apple Music is only asked about where it can be connected: agreeing to
  /// read a library the phone has no way to reach would be a grant for nothing.
  List<ConsentPurpose> get _asking =>
      widget.purposes ??
      [
        for (final p in _order)
          if (p != ConsentPurpose.appleMusicImport || AppleMusicKit.isAvailable) p,
      ];

  /// What each purpose means in one line, above the full notice.
  ///
  /// This is a signpost, not the agreement: the notice itself is one tap away
  /// and is what the grant records.
  String _summary(ConsentPurpose purpose) => switch (purpose) {
        ConsentPurpose.youtubeImport =>
          'The channels you subscribe to, the videos you liked and the videos '
              'in your playlists. Not your watch history, and not the names of '
              'your playlists.',
        ConsentPurpose.gmailReceipts =>
          'Zomato and Swiggy food receipts and Myntra delivery emails only, '
              'found by searching for those senders. No other mail is read, '
              'ever.',
        ConsentPurpose.netflixUpload =>
          'The viewing activity file you download from your own Netflix '
              'profile and upload here.',
        ConsentPurpose.spotifyImport =>
          'The listening history you download from your own Spotify '
              'account and upload here. Podcasts and private sessions are left '
              'out.',
        ConsentPurpose.appleMusicImport =>
          'The songs and albums saved in your Apple Music library, read once. '
              'Not your playlists, and Apple has no listening history to give.',
        ConsentPurpose.aiProcessing =>
          'Lets an AI suggest what is worth counting, and write the captions. '
              'It never invents a number: every value is computed here.',
        ConsentPurpose.matching =>
          'Lets us suggest people to you and show you to them. Tiles you hide '
              'from your profile still count towards who you are matched with.',
        ConsentPurpose.identityVerification =>
          'Checks your first name and date of birth against DigiLocker, once, '
              'for the verified tick. Your Aadhaar number is never shared.',
        ConsentPurpose.unknown => '',
      };

  Future<void> _showNotice(ConsentNotice notice) async {
    await showAppSheet<void>(
      context,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(notice.purpose.label, style: AppText.title3),
            const SizedBox(height: 4),
            Text('Version ${notice.version}', style: AppText.micro),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text(notice.body, style: AppText.callout),
              ),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Close',
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(ConsentState consent) async {
    if (_saving) return;
    setState(() => _saving = true);

    // Only what changed. Granting something already open would close the old
    // row and open a new one, which litters the audit trail with grants nobody
    // made.
    final toGrant = <ConsentPurpose, int>{};
    final toRevoke = <ConsentPurpose>[];

    for (final purpose in _asking) {
      final notice = consent.noticeFor(purpose);
      if (notice == null) continue;
      final already = consent.isGranted(purpose);
      final wanted = _chosen.contains(purpose);
      if (wanted && !already) toGrant[purpose] = notice.version;
      if (!wanted && already) toRevoke.add(purpose);
    }

    try {
      if (toGrant.isNotEmpty) {
        await ref.read(consentRepositoryProvider).grant(toGrant);
      }
      for (final purpose in toRevoke) {
        // Withdrawing reaches the data in the same transaction: the records
        // that source produced are purged, not just the link.
        await ref.read(consentRepositoryProvider).revoke(purpose);
      }
      if (!mounted) return;
      ref
        ..invalidate(consentProvider)
        ..invalidate(connectionsProvider)
        ..invalidate(candidatesProvider)
        ..invalidate(myProfileProvider);
      context.pop(true);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(consentProvider);

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Permissions',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      footer: consent.hasValue
          ? PrimaryButton(
              label: 'Save',
              busy: _saving,
              onPressed: () => _save(consent.requireValue),
            )
          : null,
      child: consent.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(consentProvider),
        ),
        data: (state) {
          // Start from what is already true, once. Doing this in build without
          // the latch would undo every tap.
          if (!_seeded) {
            _seeded = true;
            for (final p in _asking) {
              if (state.isGranted(p)) _chosen.add(p);
            }
          }

          final drafts = state.notices.where((n) => n.draft).isNotEmpty;

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const LargeTitle(
                'What we may read',
                subtitle: 'Each of these is a separate yes, and each can be '
                    'taken back. Taking one back deletes what it produced.',
              ),
              if (drafts)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    Insets.titleGutter,
                    0,
                    Insets.titleGutter,
                    12,
                  ),
                  child: NoteCard(
                    tone: NoteTone.warn,
                    icon: Icons.science_outlined,
                    text: 'These notices are drafts. This build is pointed at '
                        'a development server, not a real one.',
                  ),
                ),
              SectionGroup(
                footer: 'Nothing is read until you connect a source, and you '
                    'can connect them one at a time.',
                children: [
                  for (final purpose in _asking)
                    if (state.noticeFor(purpose) case final notice?)
                      AppRow(
                        label: purpose.label,
                        subtitle: _summary(purpose),
                        last: purpose == _asking.last,
                        control: AppSwitch(
                          value: _chosen.contains(purpose),
                          onChanged: (bool on) => setState(
                            () => on
                                ? _chosen.add(purpose)
                                : _chosen.remove(purpose),
                          ),
                        ),
                        onTap: () => _showNotice(notice),
                      ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.titleGutter,
                ),
                child: Text(
                  'Tap any row to read the full notice. We keep a record of '
                  'which version you agreed to and when.',
                  style: AppText.caption,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
