import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/feed_controller.dart';
import '../../../data/providers.dart';
import '../../../data/tile_media_controller.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/media.dart';
import '../../../shared/models/person.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/social.dart';
import '../../../shared/models/tile.dart' as api;
import '../../../shared/models/tile_look.dart';
import '../../../shared/widgets/ask_about_sheet.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/capture_shield.dart';
import '../../../shared/widgets/fact_chips.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/social_mark.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/swipe_to_chat.dart';
import '../../../shared/widgets/tiles.dart';
import 'arrange_wall.dart';
import 'person_actions.dart';

/// Where this screen was reached from. It changes the foot and nothing else.
enum ProfileMode {
  /// The end of setup: there is a next, and it is the rest of onboarding.
  review,

  /// From the account tab: no next, so two doors instead.
  owner,

  /// Somebody else's, which is what home is.
  viewer,

  /// Somebody else's, reached by pushing rather than by the deck: from a
  /// request waiting to be answered, or from the top of a conversation. The
  /// same wall, with a way back and no pass or ask, because the answer to this
  /// person is on the screen behind rather than on this one.
  guest,
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
  const ProfilePage({
    required this.mode,
    this.candidate,
    this.backLabel,
    this.chatAbout = false,
    this.canAsk = false,
    super.key,
  });

  final ProfileMode mode;

  /// On a guest profile, a "Chat with" button at the foot. Set where the
  /// screen behind has no answer of its own to give, which is the saved list:
  /// a request or a conversation already is one.
  final bool canAsk;

  /// On a guest profile, its tiles slide to "Chat about this" and the one
  /// chosen is popped back to the screen behind (PersonArgs.chatAbout). The
  /// deck's own profile always slides, and asks there and then.
  final bool chatAbout;

  /// Required in [ProfileMode.viewer] and [ProfileMode.guest]; ignored
  /// otherwise.
  final Candidate? candidate;

  /// What the back button names on a guest profile: the screen behind it.
  final String? backLabel;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _arranging = false;
  bool _saving = false;

  /// How long somebody else's profile must be on screen to count as a look
  /// (Aryan's call, 2026-09-26): a swipe past is not one.
  static const _lookAfter = Duration(seconds: 3);
  Timer? _look;

  @override
  void initState() {
    super.initState();
    final person = widget.candidate;
    if (_theirs && person != null) {
      _look = Timer(_lookAfter, () => _recordLook(person.userId));
    }
  }

  @override
  void dispose() {
    // Moving on to the next card, or leaving, before the time is up.
    _look?.cancel();
    super.dispose();
  }

  /// Fire and forget. Whether it counted is the server's business, and a
  /// failure here is nothing the person looking needs to hear about.
  void _recordLook(String userId) {
    unawaited(
      ref
          .read(matchingRepositoryProvider)
          .recordView(userId)
          .catchError((Object _) {}),
    );
  }

  /// The order being edited, by tile key. Null until arranging starts, so the
  /// server's order is what shows until somebody changes it.
  List<String>? _draftOrder;

  /// The deck's reading: no way back, and the pass and ask over the wall.
  bool get _viewer => widget.mode == ProfileMode.viewer;

  /// Either reading of somebody else's profile, which is the same wall built
  /// from a candidate rather than from the person's own profile.
  bool get _theirs => _viewer || widget.mode == ProfileMode.guest;

  bool get _dirty => _draftOrder != null;

  /// A guest profile with its own way to ask, from the saved list.
  bool get _askable => widget.mode == ProfileMode.guest && widget.canAsk;

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

  /// There is no publish step: a profile shows to others as soon as it passes
  /// the bar. Finishing setup only refreshes what the session knows and moves
  /// on to Home.
  Future<void> _done() async {
    try {
      final profile = await ref.read(profileRepositoryProvider).load();
      if (!mounted) return;
      ref.read(sessionProvider.notifier).onProfileChanged(profile);
      ref.invalidate(myProfileProvider);
      context.go(Routes.home);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_theirs) {
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
      // Somebody else's photos: kept out of screenshots. Your own wall is
      // yours to screenshot.
      return CaptureShield(
        child: _wall(
          name: person.displayName,
          pronouns: person.pronouns,
          verified: person.verified,
          chips: [
            ...profileFacts(
              age: person.age,
              city: person.city,
              languages: person.languages,
              education: person.education,
              company: person.company,
              smoking: person.smoking,
              drinking: person.drinking,
            ),
            // Only a match's card carries any: the server hands socials over with
            // a match and never with a feed card or a request.
            ..._socialChips(person.socials),
          ],
          photos: person.photos,
          tiles: person.tiles,
          person: person,
        ),
      );
    }

    final mine = ref.watch(myProfileProvider);
    // Your own wall shows what your matches would see: the links that are on.
    final mySocials = [
      for (final l
          in ref.watch(mySocialsProvider).valueOrNull ?? const <SocialLink>[])
        if (l.shown) l,
    ];

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
          name: details?.displayName ?? '',
          pronouns: details?.pronouns,
          verified: profile.verified,
          chips: details == null
              ? const []
              : [
                  ...profileFacts(
                    age: details.age,
                    city: details.city,
                    languages: details.languages,
                    education: details.education,
                    company: details.company,
                    smoking: details.smoking,
                    drinking: details.drinking,
                  ),
                  ..._socialChips(mySocials),
                ],
          photos: profile.photos,
          tiles: profile.tiles,
          publish: profile.publish,
        );
      },
    );
  }

  Widget _wall({
    required String name,
    required List<Fact> chips,
    Pronouns? pronouns,
    bool verified = false,
    required List<MediaAsset> photos,
    required List<api.ProfileTile> tiles,
    Candidate? person,
    PublishState? publish,
  }) {
    final shown = _ordered(tiles);
    final photosItem = _photosItem(photos);

    return AppScaffold(
      navBar: _topBar(context, person),
      footer: _theirs
          ? (_askable && person != null ? _askFoot(person) : null)
          : _foot(context, tiles, publish),
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: _viewer ? _actionsHeight : 24),
            children: [
              _header(name, pronouns, chips, photos, verified: verified),
              if (!_theirs) ...[
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
                    title: _theirs ? 'Nothing on show' : 'Your wall is empty',
                    body: _theirs
                        ? 'This person has not put anything on their profile.'
                        : 'Connect an app and pick what goes on your wall',
                    primaryLabel: _theirs ? null : 'Pick your tiles',
                    onPrimary: _theirs
                        ? null
                        : () => context.push(Routes.editSources),
                  ),
                )
              else if (_arranging)
                ArrangeWall(
                  photos: photosItem,
                  tiles: shown,
                  mediaOf: _media,
                  mediaBusy: (t) =>
                      ref.watch(tileMediaProvider).isBusy(t.kind, t.key),
                  onMedia: (t) => unawaited(_chooseMedia(t)),
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
                    if (photosItem != null) photosItem,
                    for (final t in shown)
                      BentoItem(
                        size: t.tileSize,
                        child: _chatAbout(
                          t,
                          person,
                          InsightTile(
                          size: t.tileSize,
                          number: t.isAnswer ? null : t.headline,
                          caption: t.isAnswer ? null : t.body,
                          prompt: t.question,
                          answer: t.isAnswer ? t.headline : null,
                          tone: t.tone,
                          isTrack: t.looksLikeTrack,
                          music: t.music,
                          mediaUrl: _media(t)?.stillUrl,
                          videoUrl: _media(t)?.videoUrl,
                          isLivePhoto: _media(t)?.kind == MediaKind.livePhoto,
                          // The source glyph is for the owner sorting their
                          // own wall. A viewer is being introduced to a person
                          // and does not need a filing system on the photos.
                          categoryGlyph: _theirs ? null : t.glyph,
                          ),
                        ),
                      ),
                  ],
                ),
              // The design's closing line on your own wall: what a stranger
              // does not see, and who sees the socials.
              if (!_theirs && shown.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.lock,
                          size: 13,
                          color: AppColors.label3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Anything left unpicked stays off this page. '
                          'Socials appear only if their switch is on, and '
                          'only to people you match with.',
                          style: AppText.caption.copyWith(height: 17 / 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_viewer && person != null) _viewerActions(context, person),
        ],
      ),
    );
  }

  /// What sits behind a tile. Your own wall also takes this session's
  /// uploads, so a new photo is there before the profile is pulled again; a
  /// viewer sees only what the server sent, because tile keys are shared
  /// between people and your upload is not theirs.
  /// The photos tile, first so it is always in the top row: the grid packs
  /// from the top, so the first item takes the top left. Always square,
  /// whatever else is on the wall, so a photo is never cropped wide. The rows
  /// may then come out one square short at the foot of the wall.
  ///
  /// Every photo on the profile, the main one included, so the tile is the one
  /// place to page through all of them. The main one goes last rather than
  /// first: it is already the round picture beside the name, and the tile
  /// opening on it again reads as the same photo twice.
  ///
  /// Arrange mode shows it too, pinned, so every other tile packs where it
  /// does on the wall.
  BentoItem? _photosItem(List<MediaAsset> photos) => photos.isEmpty
      ? null
      : BentoItem(
          size: TileSize.small,
          child: PhotosTile(
            photoUrls: [
              for (final p in [...photos.skip(1), photos.first]) p.stillUrl,
            ],
          ),
        );

  /// The camera on a tile in arrange mode: the same sheet as on the category
  /// page, so a photo or video can be put behind a tile, or taken off, without
  /// going through Edit tiles (Aryan, 2026-10-01). It saves at once, as it
  /// does there; only the order waits for Save.
  Future<void> _chooseMedia(api.ProfileTile tile) async {
    final has = _media(tile) != null;
    final taken = await showAppActionSheet(
      context,
      title: 'Put something behind this',
      message: tile.isAnswer
          ? 'It sits under your answer.'
          : 'It sits under the number.',
      actions: [
        const SheetAction('Photo Library', icon: Icons.photo_library_outlined),
        const SheetAction('Take Photo or Video', icon: Icons.photo_camera),
        const SheetAction('Choose File', icon: Icons.folder_outlined),
        if (has) const SheetAction('Remove', destructive: true),
      ],
    );
    if (taken == null || !mounted) return;

    void onError(String message) {
      if (mounted) showAppToast(context, message);
    }

    final controller = ref.read(tileMediaProvider.notifier);
    if (taken == 3) {
      await controller.clear(tile.kind, tile.key, onError: onError);
      return;
    }
    await controller.attach(
      tile.kind,
      tile.key,
      TileMediaSource.values[taken],
      onError: onError,
    );
  }

  MediaAsset? _media(api.ProfileTile t) => _theirs
      ? t.media
      : ref.watch(tileMediaProvider).resolve(t.kind, t.key, t.media);

  PreferredSizeWidget _topBar(BuildContext context, Candidate? person) {
    // The deck's bar is Home's: it floats over this one and carries the
    // bookmark and the "···" for the card on screen, so drawing them here too
    // would put a second set underneath, where nothing can reach them.
    if (_viewer) return const AppNavBar();
    if (_theirs) {
      return AppNavBar(
        backLabel: widget.backLabel ?? 'Back',
        onBack: () => context.pop(),
        trailing: person == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SaveProfileButton(person: person),
                  NavIconButton(
                    icon: Icons.more_horiz,
                    semanticLabel: 'More about ${person.firstName}',
                    onTap: () => showPersonMenu(
                      context,
                      ref,
                      person,
                      onBlocked: () => context.pop(),
                    ),
                  ),
                ],
              ),
      );
    }
    return AppNavBar(
      backLabel: widget.mode == ProfileMode.owner ? 'You' : 'Back',
      onBack: () => context.pop(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A four-tile icon opens arrange mode (Aryan, 2026-10-01); Done,
          // in words, closes it.
          if (_arranging)
            Pressable(
              onTap: () => setState(() => _arranging = false),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Text(
                  'Done',
                  style: AppText.navAction.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            )
          else
            NavIconButton(
              icon: Icons.grid_view_rounded,
              semanticLabel: 'Arrange your tiles',
              onTap: () => setState(() => _arranging = true),
            ),
          // Your saved list, which lives on your own profile rather than in
          // Settings. Hidden while arranging, where leaving would drop the
          // order being worked on.
          if (widget.mode == ProfileMode.owner && !_arranging)
            NavIconButton(
              icon: Icons.bookmark,
              semanticLabel: 'Saved profiles',
              onTap: () => context.push(Routes.saved),
            ),
        ],
      ),
    );
  }

  /// A chip per link, which opens the profile in its own app or the browser.
  List<Fact> _socialChips(List<SocialLink> links) => [
        for (final l in links)
          Fact(
            '',
            l.display,
            mark: SocialMark(l.network, size: 18),
            onTap: () => _openSocial(l),
          ),
      ];

  Future<void> _openSocial(SocialLink link) async {
    final uri = Uri.tryParse(link.url);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showAppToast(context, 'Could not open ${link.network.label}.');
    }
  }

  Widget _header(
    String name,
    Pronouns? pronouns,
    List<Fact> chips,
    List<MediaAsset> photos, {
    bool verified = false,
  }) {
    // Their profile shows what they stated and nothing else. Your own offers the
    // way in, because a field nobody can find is a field nobody fills.
    final pronounLine = pronouns?.label ?? (_theirs ? null : 'Add pronouns');

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Row(
              children: [
                Avatar(
                  seedColor: AppColors.fill,
                  size: 84,
                  imageUrl: photos.isEmpty ? null : photos.first.stillUrl,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title1.copyWith(
                                fontSize: 29,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          // The server's tick, never the app's: DigiLocker
                          // agreed with this first name and age.
                          if (verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              size: 22,
                              color: AppColors.blue,
                              semanticLabel: 'Verified',
                            ),
                          ],
                        ],
                      ),
                      if (pronounLine != null) ...[
                        const SizedBox(height: 3),
                        _PronounLine(
                          text: pronounLine,
                          editable: !_theirs,
                          onTap: () => context.push(Routes.editInfo),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            FactChipRow(facts: chips),
          ],
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
            ? 'Your profile is hidden. Show it again from the You tab.'
            : _blockingText(publish.blocking),
      ),
    );
  }

  /// The tile count and the category count are one rule, so they are one
  /// sentence here rather than the server's two. Anything else is the
  /// server's own message.
  static String _blockingText(List<PublishBlocker> blocking) {
    const tileRule = {Blocker.tooFewTiles, Blocker.tooFewCategories};
    return [
      if (blocking.any((b) => tileRule.contains(b.code)))
        'To make your profile discoverable, add at least 6 insight tiles '
            'across at least 3 categories',
      for (final b in blocking)
        if (!tileRule.contains(b.code)) b.message,
    ].join('. ');
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
      return Row(
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
              label: 'Done',
              onPressed: _done,
            ),
          ),
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

  /// The height of the buttons themselves, matched to the pass circle.
  static const _actionsControl = 56.0;

  /// The scrim above the buttons, long enough to fade a tile out under them.
  static const _actionsFade = 60.0;

  /// The gap between the buttons and the top of the tab bar.
  static const _aboveTabBar = 12.0;

  /// What the actions cover, which is what the wall scrolls clear of, so the
  /// last tile can be read rather than sitting under the scrim for good.
  ///
  /// The tab bar is not in this sum. The shell's scaffold extends its body
  /// under the bar and adds the bar's height to the bottom padding it hands
  /// down, so this page's safe area already ends at the top of the bar. Adding
  /// the bar again floated the buttons a whole bar's height above it.
  static const _actionsHeight = _actionsFade + _actionsControl + _aboveTabBar;

  /// Pass, or ask to chat.
  ///
  /// Their tile, sliding to "Chat about this". Somebody else's wall only, and
  /// on a guest profile only where the screen behind asked for it.
  Widget _chatAbout(api.ProfileTile t, Candidate? person, Widget tile) {
    if (person == null || !(_viewer || _askable || widget.chatAbout)) {
      return tile;
    }
    return SwipeToChat(
      onChat: () => _viewer || _askable
          ? _askAbout(person, t)
          : context.pop(t),
      child: tile,
    );
  }

  /// "Chat about this": the tile, and a line if they want one, in a sheet. From
  /// the deck the request moves it on, as the button does; from a saved
  /// profile it leaves Home alone, since this person is not the card there. If
  /// they had already asked, this accepts theirs and the chat opens on the tile.
  Future<void> _askAbout(Candidate person, api.ProfileTile tile) async {
    final deck = _viewer;
    final feed = ref.read(feedProvider.notifier);
    final repo = ref.read(matchingRepositoryProvider);
    await showAskAboutSheet(
      context,
      name: person.firstName,
      tile: tile,
      send: (note) async {
        final bool accepted;
        if (deck) {
          accepted =
              (await feed.request(person.userId, tile: tile, note: note))
                      ?.accepted ??
                  false;
        } else {
          accepted =
              (await repo.sendRequest(person.userId, tile: tile, note: note))
                  .accepted;
          ref
            ..invalidate(outgoingRequestsProvider)
            ..invalidate(incomingRequestsProvider)
            ..invalidate(conversationsProvider);
        }
        return accepted
            ? '${person.firstName} asked you too. The chat opens on this tile.'
            : 'Asked about this. ${person.firstName} will see it with your '
                'request.';
      },
    );
  }

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
          _actionsFade,
          Insets.gutter,
          _aboveTabBar,
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

  /// "Chat with" on a saved profile. No pass: passing is how the deck moves
  /// on, and there is no deck here.
  Widget _askFoot(Candidate person) => PrimaryButton(
        label: 'Chat with ${person.firstName}',
        onPressed: () => _askFromHere(person),
      );

  /// The same request the deck sends, without moving the deck: this person is
  /// not the card on Home.
  Future<void> _askFromHere(Candidate person) async {
    try {
      final result = await ref
          .read(matchingRepositoryProvider)
          .sendRequest(person.userId);
      ref
        ..invalidate(outgoingRequestsProvider)
        ..invalidate(incomingRequestsProvider)
        ..invalidate(conversationsProvider);
      if (!mounted) return;
      showAppToast(
        context,
        result.accepted
            ? '${person.firstName} asked you too. The chat is open.'
            : 'Asked. ${person.firstName} will see it in their requests.',
      );
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
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


/// One fact under the name: a glyph and a word. A social link draws its
/// network's mark instead of a glyph, and opens when tapped.
@immutable
/// The pronouns under the name, and on your own profile the way to set them.
class _PronounLine extends StatelessWidget {
  const _PronounLine({
    required this.text,
    required this.editable,
    required this.onTap,
  });

  final String text;
  final bool editable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: AppText.footnote.copyWith(
        fontSize: 15,
        height: 22.5 / 15,
        fontWeight: FontWeight.w500,
        color: editable ? AppColors.accent : null,
      ),
    );
    if (!editable) return label;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: label),
          const SizedBox(width: 5),
          const Icon(Icons.edit_outlined, size: 13, color: AppColors.accent),
        ],
      ),
    );
  }
}
