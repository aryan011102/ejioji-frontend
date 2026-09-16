import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/feed_controller.dart';
import '../../../data/providers.dart';
import '../../../shared/models/media.dart';
import '../../../shared/models/person.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/tile.dart' as api;
import '../../../shared/models/tile_look.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/tiles.dart';
import 'arrange_wall.dart';

/// Where this screen was reached from. It changes the foot and nothing else.
enum ProfileMode {
  /// The end of setup: there is a next, and it is the rest of onboarding.
  review,

  /// From the account tab: no next, so two doors instead.
  owner,

  /// Somebody else's, which is what home is.
  viewer,
}

/// The profile, all three ways it is seen.
///
/// One component rather than three screens, because they are the same wall
/// with different feet, and a copy of a wall is a wall that drifts.
///
/// The viewer reading takes its person as a parameter rather than fetching:
/// home owns the deck, and a profile that fetched its own subject would fetch
/// a different one from the card the person is looking at.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({required this.mode, this.candidate, super.key});

  final ProfileMode mode;

  /// Required in [ProfileMode.viewer]; ignored otherwise.
  final Candidate? candidate;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _arranging = false;
  bool _saving = false;

  /// The order being edited, by tile key. Null until arranging starts, so the
  /// server's order is what shows until somebody changes it.
  List<String>? _draftOrder;

  bool get _viewer => widget.mode == ProfileMode.viewer;

  bool get _dirty => _draftOrder != null;

  /// The order to render, which is the draft while arranging and the server's
  /// otherwise.
  List<api.ProfileTile> _ordered(List<api.ProfileTile> tiles) {
    final draft = _draftOrder;
    if (draft == null) return tiles;
    final byKey = {for (final t in tiles) t.key: t};
    return [
      for (final key in draft)
        if (byKey[key] != null) byKey[key]!,
    ];
  }

  void _reorder(List<api.ProfileTile> tiles, String moved, String target) {
    final order = _draftOrder ?? [for (final t in tiles) t.key];
    final next = [...order]..remove(moved);
    final at = next.indexOf(target);
    next.insert(at < 0 ? next.length : at, moved);
    setState(() => _draftOrder = next);
  }

  void _remove(List<api.ProfileTile> tiles, String key) {
    final order = _draftOrder ?? [for (final t in tiles) t.key];
    setState(() => _draftOrder = [...order]..remove(key));
  }

  /// Nothing on this screen writes until Save, arranging included. Two save
  /// rules on one screen is how people lose work.
  Future<void> _save(List<api.ProfileTile> tiles) async {
    final draft = _draftOrder;
    if (draft == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).setTiles(_ordered(tiles));
      final profile = await ref.read(profileRepositoryProvider).load();
      if (!mounted) return;
      ref.read(sessionProvider.notifier).onProfileChanged(profile);
      ref.invalidate(myProfileProvider);
      setState(() {
        _draftOrder = null;
        _arranging = false;
      });
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    try {
      final publish = await ref.read(profileRepositoryProvider).publish();
      if (!mounted) return;
      ref.read(sessionProvider.notifier).onPublishChanged(publish);
      ref.invalidate(myProfileProvider);
      if (publish.visible) {
        context.go(Routes.home);
      } else {
        // The server decides, and it returns why. Showing its first reason
        // beats a generic refusal, and beats the client trying to guess the
        // rule for itself.
        showAppToast(
          context,
          publish.blocking.isEmpty
              ? 'Your profile is not showing yet.'
              : publish.blocking.first.message,
        );
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  Future<void> _moreSheet(Candidate person) async {
    final choice = await showAppActionSheet(
      context,
      message: '${person.firstName} is never told either way.',
      actions: [
        const SheetAction('Report profile', destructive: true),
        SheetAction('Block ${person.firstName}', destructive: true),
      ],
    );
    if (!mounted) return;

    if (choice == 0) {
      unawaited(context.push<void>(Routes.reportFor(person.userId)));
    } else if (choice == 1) {
      try {
        // Blocking is two-way and immediate: it ends any match, declines a
        // pending request in either direction, and takes them out of both
        // feeds.
        await ref.read(matchingRepositoryProvider).block(person.userId);
        if (!mounted) return;
        ref.read(feedProvider.notifier).dropCurrent();
        showAppToast(context, '${person.firstName} is blocked.');
      } on ApiException catch (e) {
        if (mounted) showAppToast(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewer) {
      final person = widget.candidate;
      if (person == null) {
        return const AppScaffold(
          child: EmptyState(
            icon: Icons.person_outline,
            title: 'Nobody to show',
            body: 'This profile could not be loaded.',
          ),
        );
      }
      return _wall(
        name: person.firstName,
        subtitle: '${person.age} · ${person.city.label}',
        photos: person.photos,
        tiles: person.tiles,
        person: person,
      );
    }

    final mine = ref.watch(myProfileProvider);

    return mine.when(
      loading: () => const AppScaffold(child: LoadingView()),
      error: (e, _) => AppScaffold(
        navBar: AppNavBar(backLabel: 'You', onBack: () => context.pop()),
        child: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
      ),
      data: (profile) {
        final details = profile.profile;
        return _wall(
          name: details?.firstName ?? '',
          subtitle: details == null
              ? ''
              : '${details.age} · ${details.city.label}',
          photos: profile.photos,
          tiles: profile.tiles,
          publish: profile.publish,
        );
      },
    );
  }

  Widget _wall({
    required String name,
    required String subtitle,
    required List<MediaAsset> photos,
    required List<api.ProfileTile> tiles,
    Candidate? person,
    PublishState? publish,
  }) {
    final shown = _ordered(tiles);
    final columnsUsed =
        shown.fold<int>(0, (sum, t) => sum + t.tileSize.columns);

    return AppScaffold(
      navBar: _topBar(context, person),
      footer: _viewer ? null : _foot(context, tiles, publish),
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: _viewer ? 210 : 24),
            children: [
              _header(name, subtitle, photos),
              if (!_viewer) ...[
                if (publish != null) _publishState(publish),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.titleGutter,
                    14,
                    Insets.titleGutter,
                    0,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 15,
                        color: AppColors.label3,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'This is the profile as everyone else sees it.',
                          style: AppText.caption.copyWith(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: EmptyState(
                    icon: Icons.grid_view_outlined,
                    title: _viewer ? 'Nothing on show' : 'Your wall is empty',
                    body: _viewer
                        ? 'This person has not put anything on their profile.'
                        : 'Connect something, or answer a few questions, and '
                            'pick what goes on your wall.',
                    primaryLabel: _viewer ? null : 'Pick your tiles',
                    onPrimary: _viewer
                        ? null
                        : () => context.push(Routes.editSources),
                  ),
                )
              else if (_arranging)
                ArrangeWall(
                  tiles: shown,
                  onReorder: (moved, target) => _reorder(tiles, moved, target),
                  onRemove: (key) => _remove(tiles, key),
                  onFloorHit: () => showAppToast(
                    context,
                    'Six is the fewest a profile can show. Add another before '
                    'taking one off.',
                  ),
                )
              else
                BentoGrid(
                  children: [
                    for (final t in shown)
                      BentoItem(
                        size: t.tileSize,
                        child: InsightTile(
                          size: t.tileSize,
                          number: t.isAnswer ? null : t.headline,
                          caption: t.isAnswer ? null : t.body,
                          prompt: t.question,
                          answer: t.isAnswer ? t.headline : null,
                          tone: t.tone,
                          isTrack: t.looksLikeTrack,
                          // The source glyph is for the owner sorting their
                          // own wall. A viewer is being introduced to a person
                          // and does not need a filing system on the photos.
                          categoryGlyph: _viewer ? null : t.glyph,
                        ),
                      ),
                    if (photos.length > 1)
                      BentoItem(
                        size: columnsUsed.isOdd
                            ? TileSize.small
                            : TileSize.wide,
                        child: PhotosTile(
                          photoUrls: [
                            for (final p in photos.skip(1)) p.stillUrl,
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (_viewer && person != null) _viewerActions(context, person),
        ],
      ),
    );
  }

  PreferredSizeWidget _topBar(BuildContext context, Candidate? person) {
    if (_viewer) {
      return AppNavBar(
        backLabel: null,
        trailingLabel: '···',
        onTrailing: person == null ? null : () => _moreSheet(person),
      );
    }
    return AppNavBar(
      backLabel: widget.mode == ProfileMode.owner ? 'You' : 'Back',
      onBack: () => context.pop(),
      trailingLabel: _arranging ? 'Done' : 'Arrange',
      onTrailing: () => setState(() => _arranging = !_arranging),
    );
  }

  Widget _header(String name, String subtitle, List<MediaAsset> photos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 4, Insets.gutter, 0),
      child: Row(
        children: [
          Avatar(
            seedColor: AppColors.fill,
            size: 74,
            imageUrl: photos.isEmpty ? null : photos.first.stillUrl,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title1.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppText.footnote.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Whether this profile is out there, and what is missing if not.
  ///
  /// Shown rather than hidden because a profile can stop being visible without
  /// the person doing anything: withdrawing consent for a source empties the
  /// tiles it fed, and the wall can fall below the bar on its own.
  Widget _publishState(PublishState publish) {
    if (publish.underReview) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          Insets.titleGutter,
          16,
          Insets.titleGutter,
          0,
        ),
        child: NoteCard(
          tone: NoteTone.warn,
          icon: Icons.pause_circle_outline,
          text: 'A moderator is looking at your profile, so it is hidden for '
              'now. You cannot send new chat requests until that is done.',
        ),
      );
    }

    if (publish.visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.titleGutter,
        16,
        Insets.titleGutter,
        0,
      ),
      child: NoteCard(
        icon: Icons.visibility_off_outlined,
        text: publish.blocking.isEmpty
            ? 'Your profile is not showing to anyone. Publish it when you are '
                'ready.'
            : publish.blocking.map((b) => b.message).join('. '),
      ),
    );
  }

  Widget _foot(
    BuildContext context,
    List<api.ProfileTile> tiles,
    PublishState? publish,
  ) {
    if (_dirty) {
      return Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Discard',
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _draftOrder = null;
                        _arranging = false;
                      }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: 'Save changes',
              busy: _saving,
              onPressed: () => _save(tiles),
            ),
          ),
        ],
      );
    }

    if (widget.mode == ProfileMode.review) {
      final ready = publish?.canPublish ?? false;
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Edit profile',
                  onPressed: () => context.push(Routes.editSources),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Publish my profile',
                  onPressed: ready ? _publish : null,
                ),
              ),
            ],
          ),
          if (!ready && publish != null && publish.blocking.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              publish.blocking.first.message,
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            label: 'Edit info',
            onPressed: () => context.push(Routes.editInfo),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SecondaryButton(
            label: 'Edit tiles',
            onPressed: () => context.push(Routes.editSources),
          ),
        ),
      ],
    );
  }

  /// Pass, or ask to chat.
  ///
  /// There is no like and no gate: the ask goes straight out, and the other
  /// person answers it in their own time. Asking somebody who already asked
  /// you accepts theirs, which the server decides and says so in its answer.
  Widget _viewerActions(BuildContext context, Candidate person) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          60,
          Insets.gutter,
          100,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), AppColors.group],
            stops: [0, 0.62],
          ),
        ),
        child: Row(
          children: [
            Pressable(
              onTap: () => ref.read(feedProvider.notifier).pass(person.userId),
              semanticLabel: 'Pass on ${person.firstName}',
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.row,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Icon(
                  Icons.close,
                  size: 22,
                  color: AppColors.label2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Chat with ${person.firstName}',
                onPressed: () => _ask(person),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ask(Candidate person) async {
    try {
      final result = await ref.read(feedProvider.notifier).request(person.userId);
      if (!mounted || result == null) return;
      showAppToast(
        context,
        result.accepted
            // They had already asked. Asking back accepts theirs rather than
            // opening a second request, so this is a match, not a request.
            ? '${person.firstName} asked you too. The chat is open.'
            : 'Asked. ${person.firstName} will see it in their requests.',
      );
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }
}
