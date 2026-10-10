import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/routes.dart';
import '../../../core/native/apple_music_kit.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/connect_controller.dart';
import '../../../data/providers.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/consent.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';
import '../../insights/presentation/category_page.dart';
import 'ai_consent_sheet.dart';

/// What the profile is actually made of, and the one screen that deals with it.
///
/// Six sources, Apple Music only on an iPhone. The original design offered
/// nine, including some that have no way in at all: LinkedIn work history
/// needs partner access nobody gets, and Apple Health's terms forbid what we
/// would do with it. Offering a connect button for those is a promise the
/// product cannot keep. The layout is the design's; the list is what exists.
///
/// Instagram is a source since 2026-10-10, as Netflix is: no API, so the
/// person uploads their own download (instagram_upload_page.dart). Its tiles
/// are Social. The Instagram, X and LinkedIn handles shown to matches are not
/// sources and moved to Edit info the same day (Aryan's call), so a handle and
/// a source are never side by side here.
///
/// Every source is read exactly once, when it is connected. There is no
/// background sync: the access token lives in the server's memory for the
/// couple of minutes the read takes and is revoked when it finishes, so there
/// is never a stored credential to leak.
///
/// Onboarding and Edit tiles open this same screen. Nothing here shows tiles:
/// Next walks the categories, and a category the sources could not fill asks
/// its questions there instead. A connected row opens what can be done to it,
/// reading it again or disconnecting it.
///
/// Gmail can be more than one inbox: a personal address and a work one hold
/// different receipts. Each connected inbox is its own row, under its address,
/// with what was read from it, and "Add another account" connects the next.
/// Removing one inbox deletes what was read from it and leaves the others.
class ConnectAccountsPage extends ConsumerStatefulWidget {
  const ConnectAccountsPage({this.editing = false, super.key});

  /// Opened from the profile rather than during setup: a back button, and Next
  /// walks the categories in edit mode, saving each one as it goes.
  final bool editing;

  @override
  ConsumerState<ConnectAccountsPage> createState() =>
      _ConnectAccountsPageState();
}

/// One source in the list, and the line it shows before it is connected.
typedef _Source = ({SourceProvider provider, String name, String note});

class _ConnectAccountsPageState extends ConsumerState<ConnectAccountsPage> {
  /// The design's groups, holding only the sources that exist on this phone.
  /// Spotify is an upload here rather than a sign-in, and says so. Apple Music
  /// is a sign-in, and only where MusicKit is (an iPhone).
  static final _groups = <(String, List<_Source>)>[
    (
      'Music',
      [
        if (AppleMusicKit.isAvailable)
          (
            provider: SourceProvider.appleMusic,
            name: 'Apple Music',
            note: 'Your library · no listening history',
          ),
        (
          provider: SourceProvider.spotify,
          name: 'Spotify',
          note: 'Manual · the listening history you download',
        ),
      ],
    ),
    (
      'Watching',
      [
        (
          provider: SourceProvider.youtube,
          name: 'YouTube',
          note: 'Subscriptions and likes · no watch history',
        ),
      ],
    ),
    (
      'Email receipts',
      [
        (
          provider: SourceProvider.gmail,
          name: 'Gmail',
          note: 'Order receipts only · no other mail is read',
        ),
      ],
    ),
    (
      'No public API — add these yourself',
      [
        (
          provider: SourceProvider.netflix,
          name: 'Netflix',
          note: 'The watch history you download',
        ),
        (
          provider: SourceProvider.instagram,
          name: 'Instagram',
          note: 'Who you follow and what you like · the download you ask for',
        ),
      ],
    ),
  ];

  static final _sourceCount = _groups.fold(0, (n, g) => n + g.$2.length);

  /// How many inboxes the server lets one person connect. It refuses past this
  /// anyway; stopping here only spares a trip through Google's screens.
  static const _maxInboxes = 5;

  /// A read again or a disconnect in progress. Connecting has its own state in
  /// [connectProvider].
  SourceProvider? _busy;

  /// The one inbox being refreshed or removed, when there are several.
  String? _busyInbox;

  /// Tile keys this person has already been shown in Edit tiles, kept on
  /// this phone. A tile not in it is new: a refresh found it. Null until
  /// read, and on the first visit it is filled with everything on screen, so
  /// nothing is called new until something actually arrives.
  Set<String>? _seen;
  bool _seenRead = false;

  String? get _seenKey => switch (ref.read(sessionProvider).userId) {
        final id? => 'tiles_seen:$id',
        null => null,
      };

  Future<void> _readSeen() async {
    final key = _seenKey;
    Set<String>? stored;
    try {
      if (key != null) {
        stored = (await SharedPreferences.getInstance())
            .getStringList(key)
            ?.toSet();
      }
    } on Object {
      // No storage: nothing is ever called new, which is the quiet failure.
    }
    if (mounted) {
      setState(() {
        _seen = stored;
        _seenRead = true;
      });
    }
  }

  /// Remembers [keys] as seen, keeping only tiles that still exist so the
  /// list does not grow forever.
  void _markSeen(Iterable<String> keys, Iterable<String> current) {
    final now = {...?_seen, ...keys}.intersection(current.toSet());
    setState(() => _seen = now);
    final key = _seenKey;
    if (key == null) return;
    unawaited(() async {
      try {
        await (await SharedPreferences.getInstance())
            .setStringList(key, now.toList());
      } on Object {
        // Shown as new again next time; nothing worse.
      }
    }());
  }

  @override
  void initState() {
    super.initState();
    if (widget.editing) unawaited(_readSeen());
    // The AI question, during setup, before anything is read: a yes then
    // covers the first source's insights (ai_consent_sheet.dart).
    if (!widget.editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(askAboutAiOnce(context, ref));
      });
    }
  }

  void _refetch() {
    ref
      ..invalidate(connectionsProvider)
      ..invalidate(candidatesProvider)
      ..invalidate(myProfileProvider)
      ..invalidate(consentProvider);
  }

  Future<void> _connect(SourceProvider provider, ConsentState consent) async {
    // Consent first, always: the server refuses to authorize a source whose
    // purpose is not open. Tapping the source is the yes (Aryan, 2026-10-01):
    // it is granted at the current notice with no screen of its own, as
    // Matching and DigiLocker are. It is still its own row, recorded with the
    // notice version, and still withdrawn in Settings or by disconnecting.
    if (!consent.canConnect(provider)) {
      try {
        await ref.read(consentRepositoryProvider).grantNow(provider.purpose);
      } on ApiException catch (e) {
        if (mounted) showAppToast(context, e.message);
        return;
      }
      ref.invalidate(consentProvider);
      if (!mounted) return;
    }
    await _read(provider, declined: 'No problem. Nothing was read.');
  }

  /// Reads a source: Google's screen or Apple's prompt for the sign-ins, the
  /// file for the two uploads. Reading again is the same thing under a fresh permission,
  /// never a sync.
  Future<void> _read(SourceProvider provider, {String? declined}) async {
    switch (provider) {
      case SourceProvider.netflix:
        await context.push(
          Routes.upload(Routes.netflixUpload, editing: widget.editing),
        );
        return;
      case SourceProvider.spotify:
        await context.push(
          Routes.upload(Routes.spotifyUpload, editing: widget.editing),
        );
        return;
      case SourceProvider.instagram:
        await context.push(
          Routes.upload(Routes.instagramUpload, editing: widget.editing),
        );
        return;
      default:
        break;
    }
    try {
      final run = await ref.read(connectProvider.notifier).begin(provider);
      if (!mounted) return;
      if (run == null) {
        // They said no on the provider's own screen. That is an answer, not a
        // failure, and it is not re-asked in this session.
        if (declined != null) showAppToast(context, declined);
        return;
      }
      await context.push(Routes.readingRun(run.id, editing: widget.editing));
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// What a connected row opens.
  Future<void> _manage(SourceProvider provider, String name) async {
    final choice = await showAppActionSheet(
      context,
      title: '$name · connected',
      message: 'Disconnecting deletes everything we derived from it, not just '
          'the link.',
      actions: const [
        SheetAction('What we read', icon: Icons.visibility_outlined),
        SheetAction('Refresh data', icon: Icons.refresh),
        SheetAction(
          'Disconnect',
          icon: Icons.remove_circle_outline,
          destructive: true,
        ),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 0:
        await context.push(
          '${Routes.consent}?purpose=${provider.purpose.wire}',
        );
      case 1:
        setState(() => _busy = provider);
        try {
          await _read(provider);
        } finally {
          if (mounted) setState(() => _busy = null);
        }
      case 2:
        await _disconnect(provider, name);
    }
  }

  /// Disconnecting withdraws the permission, and the server deletes what that
  /// source produced in the same step: its records, its tiles, and those
  /// tiles' places on the profile.
  Future<void> _disconnect(SourceProvider provider, String name) async {
    setState(() => _busy = provider);
    try {
      await ref.read(consentRepositoryProvider).revoke(provider.purpose);
      if (!mounted) return;
      _refetch();
      showAppToast(context, '$name is disconnected.');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// What a connected inbox opens. With several, removing one is its own
  /// action and the permission stays for the rest. With one, it is the same
  /// disconnect every other source has.
  Future<void> _manageInbox(Connection inbox, {required bool only}) async {
    final name = inbox.address ?? 'Gmail';
    final choice = await showAppActionSheet(
      context,
      title: '$name · connected',
      message: only
          ? 'Disconnecting deletes everything we derived from it, not just '
              'the link.'
          : 'Removing this inbox deletes everything we read from it. Your '
              'other inboxes stay connected.',
      actions: [
        const SheetAction('What we read', icon: Icons.visibility_outlined),
        const SheetAction('Refresh data', icon: Icons.refresh),
        SheetAction(
          only ? 'Disconnect' : 'Remove this inbox',
          icon: Icons.remove_circle_outline,
          destructive: true,
        ),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 0:
        await context.push(
          '${Routes.consent}?purpose=${SourceProvider.gmail.purpose.wire}',
        );
      case 1:
        // Google's account chooser opens first: picking this inbox again
        // refreshes it, and picking another connects that one instead.
        setState(() => _busyInbox = inbox.id);
        try {
          await _read(SourceProvider.gmail);
        } finally {
          if (mounted) setState(() => _busyInbox = null);
        }
      case 2:
        if (only) {
          await _disconnect(SourceProvider.gmail, 'Gmail');
        } else {
          await _removeInbox(inbox, name);
        }
    }
  }

  Future<void> _removeInbox(Connection inbox, String name) async {
    setState(() => _busyInbox = inbox.id);
    try {
      await ref.read(sourcesRepositoryProvider).removeConnection(inbox.id);
      if (!mounted) return;
      _refetch();
      showAppToast(context, '$name is removed.');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busyInbox = null);
    }
  }

  /// The rows for one source. Gmail is one row per connected inbox and a way
  /// to add the next; every other source is one row.
  List<Widget> _rows(
    _Source s, {
    required Map<SourceProvider, Connection> linked,
    required List<Connection> inboxes,
    required SourceProvider? connecting,
    required ConsentState? consent,
    required bool locked,
  }) {
    if (s.provider == SourceProvider.gmail && inboxes.isNotEmpty) {
      return [
        for (final inbox in inboxes)
          _SourceRow(
            source: s,
            title: inbox.address,
            connection: inbox,
            busy: _busyInbox == inbox.id ||
                (_busy == SourceProvider.gmail && inboxes.length == 1),
            last: false,
            onTap: locked
                ? null
                : () => _manageInbox(inbox, only: inboxes.length == 1),
          ),
        if (inboxes.length < _maxInboxes)
          _AddAccountRow(
            busy: connecting == SourceProvider.gmail && _busyInbox == null,
            onTap: locked
                ? null
                : () => _connect(SourceProvider.gmail, consent!),
          ),
      ];
    }
    return [
      _SourceRow(
        source: s,
        connection: linked[s.provider],
        busy: connecting == s.provider || _busy == s.provider,
        last: false,
        onTap: locked
            ? null
            : linked.containsKey(s.provider)
                ? () => _manage(s.provider, s.name)
                : () => _connect(s.provider, consent!),
      ),
    ];
  }

  /// Edit tiles: the categories, grouped by the apps that fill them, each
  /// group its own box, always open (Aryan, 2026-10-01). Null until the four
  /// reads land, and then the page falls back to the plain list of sources.
  ///
  /// A group is a set of apps: Gmail holds food, going out, travel, shopping
  /// and moving; Netflix holds Netflix; Music is filled by YouTube, Spotify
  /// and Apple Music together, so it is one box with their marks stacked in
  /// its header rather than a Music row under each of them. Read off the
  /// tiles themselves, so a person whose music comes only from Spotify sees it
  /// under Spotify. An app on this phone that fills nothing yet (not
  /// connected, or nothing found) joins the box of the category it would fill
  /// (Spotify and Apple Music the Music box), or gets a header of its own,
  /// which is how it is connected from here. Categories only questions fill
  /// come last, and only the ones the person answered.
  ///
  /// A header opens what can be done to its apps; a category row opens the
  /// category. Tiles a refresh brought in carry "New" on their app's header
  /// and on their category until that category is opened.
  List<Widget>? _tilesGroup({
    required Map<SourceProvider, Connection> linked,
    required List<Connection> inboxes,
    required ConsentState? consent,
    required bool locked,
  }) {
    final candidates = ref.watch(candidatesProvider).valueOrNull;
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final bank = ref.watch(promptBankProvider).valueOrNull;
    if (candidates == null || profile == null || bank == null) return null;
    final categories = pickableCategories(candidates, bank.answers, bank);

    // New since this phone last showed them. The first visit only remembers.
    final allKeys = [for (final c in candidates) c.key];
    if (_seenRead && _seen == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _seen == null) _markSeen(allKeys, allKeys);
      });
    }
    final seen = _seen;
    final fresh = [
      for (final c in candidates)
        if (seen != null && !seen.contains(c.key)) c,
    ];
    bool isNew(Iterable<SourceProvider> apps, TileCategory? category) =>
        fresh.any(
          (c) =>
              (category == null || c.category == category) &&
              c.providers.any(apps.contains),
        );

    // Which apps fill each category, in the order the apps are listed.
    // Watching and Netflix count as one box, so both rows sit under
    // "YouTube · Netflix" (Pritika, 2026-10-04).
    List<SourceProvider> appsOf(TileCategory c) => [
          for (final source in _tileSources)
            if (candidates.any(
              (i) =>
                  _boxOf(i.category) == _boxOf(c) &&
                  i.providers.contains(source),
            ))
              source,
        ];
    final groups = <(List<SourceProvider>, List<TileCategory>)>[];
    final asked = <TileCategory>[];
    for (final c in categories) {
      final apps = appsOf(c);
      if (apps.isEmpty) {
        // Only what they answered during setup (Aryan, 2026-10-01): Edit
        // tiles edits, it does not offer questions nobody took up.
        if (bank.answers.any((a) => a.category == c)) asked.add(c);
        continue;
      }
      final i = groups.indexWhere((g) => _sameApps(g.$1, apps));
      if (i < 0) {
        groups.add((apps, [c]));
      } else {
        groups[i].$2.add(c);
      }
    }
    // An app filling nothing joins the box of the category it would fill.
    final shown = {for (final (apps, _) in groups) ...apps};
    for (final source in _tileSources) {
      if (shown.contains(source) || !_onThisPhone(source)) continue;
      final home = _homeOf[source];
      final i = home == null
          ? -1
          : groups.indexWhere(
              (g) =>
                  g.$2.any((c) => _boxOf(c) == _boxOf(home)) ||
                  (g.$2.isEmpty &&
                      g.$1.any(
                        (a) =>
                            _boxOf(_homeOf[a] ?? TileCategory.unknown) ==
                            _boxOf(home),
                      )),
            );
      if (i < 0) {
        groups.add(([source], <TileCategory>[]));
      } else {
        groups[i] = (
          [
            for (final a in _tileSources)
              if (groups[i].$1.contains(a) || a == source) a,
          ],
          groups[i].$2,
        );
      }
    }
    // In app order, a box of one app before a shared one; questions last.
    int first(List<SourceProvider> apps) =>
        apps.map(_tileSources.indexOf).reduce(math.min);
    groups.sort((x, y) {
      final byApp = first(x.$1).compareTo(first(y.$1));
      return byApp != 0 ? byApp : x.$1.length.compareTo(y.$1.length);
    });
    if (asked.isNotEmpty) groups.add((const <SourceProvider>[], asked));

    int onProfile(Iterable<TileCategory> cs) =>
        profile.tiles.where((t) => cs.contains(t.category)).length;
    String? count(int n) => n == 0 ? null : '$n on profile';

    return [
      for (final (g, (apps, cs)) in groups.indexed)
        _Group(
          header: g == 0
              ? 'Your tiles · ${profile.tiles.length}/${bank.maxProfileTiles} '
                  'on your profile'
              : null,
          top: g == 0 ? 26 : 12,
          children: [
            AppRow(
              leading: switch (apps) {
                [] => const Icon(
                    Icons.edit_note,
                    size: 22,
                    color: AppColors.label2,
                  ),
                [final one] => _BrandMark(one),
                _ => _StackedMarks(apps),
              },
              label: switch (apps) {
                [] => 'Your answers',
                [final one] => _appName(one),
                _ => apps.map(_appName).join(' · '),
              },
              tag: isNew(apps, null) ? 'New' : null,
              subtitle: apps.isNotEmpty && !apps.any(linked.containsKey)
                  ? 'Not connected'
                  : null,
              value: count(onProfile(cs)),
              last: cs.isEmpty,
              onTap: apps.isEmpty || locked
                  ? null
                  : () => unawaited(
                        _openApps(
                          apps,
                          linked: linked,
                          inboxes: inboxes,
                          consent: consent,
                        ),
                      ),
            ),
            for (final (j, c) in cs.indexed)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: AppRow(
                  leading: Text(c.glyph, style: const TextStyle(fontSize: 17)),
                  label: c.label,
                  tag: isNew(apps, c) ? 'New' : null,
                  value: count(onProfile([c])),
                  last: j == cs.length - 1,
                  onTap: () {
                    _markSeen(
                      [
                        for (final i in candidates)
                          if (i.category == c) i.key,
                      ],
                      allKeys,
                    );
                    context.push(
                      Routes.editCategoryOnly(categories.indexOf(c)),
                    );
                  },
                ),
              ),
          ],
        ),
    ];
  }

  /// The category an app's tiles would land in, so an app that has filled
  /// nothing yet can sit in that category's box. Gmail fills several, so it
  /// stands on its own.
  static const _homeOf = <SourceProvider, TileCategory>{
    SourceProvider.youtube: TileCategory.watching,
    SourceProvider.netflix: TileCategory.netflix,
    SourceProvider.spotify: TileCategory.music,
    SourceProvider.appleMusic: TileCategory.music,
    SourceProvider.instagram: TileCategory.social,
  };

  /// The box a category's row sits in: Netflix shares Watching's, so YouTube
  /// and Netflix are one "YouTube · Netflix" box, as the music apps are one.
  /// The categories themselves stay apart, each with its own two tiles.
  static TileCategory _boxOf(TileCategory c) =>
      c == TileCategory.netflix ? TileCategory.watching : c;

  static bool _sameApps(List<SourceProvider> a, List<SourceProvider> b) =>
      a.length == b.length && a.every(b.contains);

  /// Whether this phone can connect [source] at all: Apple Music is a sign-in
  /// only where MusicKit is.
  static bool _onThisPhone(SourceProvider source) =>
      source != SourceProvider.appleMusic || AppleMusicKit.isAvailable;

  static String _appName(SourceProvider source) =>
      source == SourceProvider.gmail ? 'Gmail' : source.label;

  /// A header tapped. Gmail opens its inboxes and "Add another account"; any
  /// other app connected opens its usual three options (what we read, refresh,
  /// disconnect), and one not connected connects. A shared header (Music)
  /// first asks which of its apps.
  Future<void> _openApps(
    List<SourceProvider> apps, {
    required Map<SourceProvider, Connection> linked,
    required List<Connection> inboxes,
    required ConsentState? consent,
  }) async {
    var app = apps.first;
    if (apps.length > 1) {
      final i = await showAppActionSheet(
        context,
        title: apps.map(_appName).join(' · '),
        actions: [
          for (final a in apps)
            SheetAction(
              linked.containsKey(a) ? _appName(a) : 'Connect ${_appName(a)}',
              icon: linked.containsKey(a) ? Icons.link : Icons.add,
            ),
        ],
      );
      if (i == null || !mounted) return;
      app = apps[i];
    }
    if (consent == null) return;
    if (app == SourceProvider.gmail && inboxes.isNotEmpty) {
      final canAdd = inboxes.length < _maxInboxes;
      final i = await showAppActionSheet(
        context,
        title: 'Gmail',
        actions: [
          for (final inbox in inboxes)
            SheetAction(
              inbox.address ?? 'Gmail',
              icon: Icons.mail_outline,
            ),
          if (canAdd)
            const SheetAction('Add another account', icon: Icons.add),
        ],
      );
      if (i == null || !mounted) return;
      if (i < inboxes.length) {
        await _manageInbox(inboxes[i], only: inboxes.length == 1);
      } else {
        await _connect(SourceProvider.gmail, consent);
      }
      return;
    }
    if (linked.containsKey(app)) {
      await _manage(app, _appName(app));
    } else {
      await _connect(app, consent);
    }
  }

  /// The apps, in the order their groups appear under "Your tiles".
  static const _tileSources = [
    SourceProvider.gmail,
    SourceProvider.youtube,
    SourceProvider.netflix,
    SourceProvider.spotify,
    SourceProvider.appleMusic,
    SourceProvider.instagram,
  ];

  void _next() => context.push(
        widget.editing ? Routes.editCategoryAt(0) : Routes.pickCategoryAt(0),
      );

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(consentProvider);
    final connections = ref.watch(connectionsProvider);
    final connecting = ref.watch(connectProvider);

    final active = [
      for (final c in connections.valueOrNull ?? const <Connection>[])
        if (c.isActive) c,
    ];
    // By source, the first account of each: what the strength card and Next
    // count. Several inboxes are still one source.
    final linked = <SourceProvider, Connection>{
      for (final c in active.reversed) c.provider: c,
    };
    final inboxes = [
      for (final c in active)
        if (c.provider == SourceProvider.gmail) c,
    ];
    final locked = connecting != null ||
        _busy != null ||
        _busyInbox != null ||
        !consent.hasValue;
    final tiles = widget.editing
        ? _tilesGroup(
            linked: linked,
            inboxes: inboxes,
            consent: consent.valueOrNull,
            locked: locked,
          )
        : null;

    return AppScaffold(
      navBar: widget.editing
          ? AppNavBar(backLabel: 'Profile', onBack: () => context.pop())
          : null,
      // Setup walks every category once. Editing is usually one thing, so it
      // is the list of categories at the top instead of a walk.
      footer: widget.editing
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(
                  label: 'Next',
                  onPressed: linked.isNotEmpty ? _next : null,
                ),
                // Nothing connected still has a way on: every category comes
                // back thin, so the walk is all questions.
                if (linked.isEmpty)
                  TextActionButton(
                    label: "I'll do this later",
                    dim: true,
                    onPressed: _next,
                  ),
              ],
            ),
      child: connections.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: _refetch),
        data: (_) => ListView(
          padding: EdgeInsets.only(top: widget.editing ? 0 : 12, bottom: 22),
          children: [
            const _Heading(),
            _ReadOnceCard(onTap: () => context.push(Routes.consent)),
            _StrengthCard(linked: linked, of: _sourceCount),
            // Edit tiles: the tiles grouped by app, every app reached from its
            // header, in place of the list of sources (Aryan, 2026-10-01).
            if (tiles != null)
              ...tiles
            else
              for (final (header, sources) in _groups)
                _Group(
                  header: header,
                  children: _lastMarked([
                    for (final s in sources)
                      ..._rows(
                        s,
                        linked: linked,
                        inboxes: inboxes,
                        connecting: connecting,
                        consent: consent.valueOrNull,
                        locked: locked,
                      ),
                  ]),
                ),
            if (!widget.editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.titleGutter,
                  18,
                  Insets.titleGutter,
                  0,
                ),
                child: Text(
                  'You can add, refresh or remove any source later from Edit '
                  'tiles on your profile.',
                  style: AppText.caption.copyWith(height: 17 / 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.titleGutter,
        4,
        Insets.titleGutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Complete your profile', style: AppText.largeTitle),
          const SizedBox(height: 6),
          Text(
            'We match on how you actually live, based on real data from the '
            'apps you already use. Connect the apps you are comfortable with.',
            style: AppText.callout.copyWith(height: 20 / 15),
          ),
        ],
      ),
    );
  }
}

/// The promise, in one card, with the full notices behind it.
class _ReadOnceCard extends StatelessWidget {
  const _ReadOnceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppText.caption.copyWith(
      fontSize: 12.5,
      height: 17 / 12.5,
      color: AppColors.label2,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 16, Insets.gutter, 0),
      child: Pressable(
        onTap: onTap,
        semanticLabel: 'What we read',
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: _panel,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.lock, size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      const TextSpan(text: 'Each account is read '),
                      TextSpan(
                        text: 'once',
                        style: style.copyWith(
                          color: AppColors.label,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: ', then disconnected. We keep insights, never '
                            'your messages, and we can never post as you. ',
                      ),
                      TextSpan(
                        text: 'What we read',
                        style: style.copyWith(color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.label3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How much there is to match on: a word, six segments and a line.
///
/// It counts connected sources, since that is what this screen changes. With
/// five sources (an iPhone) the segments go 0, 1, 2, 4, 5, 6, and with four
/// 0, 2, 3, 5, 6, so each source visibly moves the bar and the last one fills
/// it.
class _StrengthCard extends StatelessWidget {
  const _StrengthCard({required this.linked, required this.of});

  final Map<SourceProvider, Connection> linked;
  final int of;

  static const _segments = 6;

  @override
  Widget build(BuildContext context) {
    final n = linked.length;
    final filled = (n * _segments / math.max(of, 1)).round();
    final (word, line) = switch (n) {
      0 => ('Empty', 'Nothing connected yet.'),
      1 => (
          'Thin',
          'A start. Music and watching sharpen taste matching the most.',
        ),
      _ when n < of => (
          'Good',
          linked.containsKey(SourceProvider.gmail)
              ? 'Enough to match on.'
              : 'Enough to match on. Receipts add how you actually spend a '
                  'weekend.',
        ),
      _ => ('Strong', 'Everything from here only refines the edges.'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 20, Insets.gutter, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
        decoration: _panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile strength',
                    style: AppText.bodyStrong.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Text(
                  word,
                  style: AppText.footnote.copyWith(
                    fontWeight: FontWeight.w700,
                    color: n >= 2 ? AppColors.ok : AppColors.label2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                for (var i = 0; i < _segments; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < filled ? AppColors.fill : AppColors.fill3,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 9),
            Text(line, style: AppText.caption.copyWith(height: 16 / 12)),
          ],
        ),
      ),
    );
  }
}

/// A sentence-case header over one rounded plate of rows.
class _Group extends StatelessWidget {
  const _Group({required this.header, required this.children, this.top = 26});

  /// Null for a box that follows another under the same heading.
  final String? header;
  final List<Widget> children;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Insets.gutter, top, Insets.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header case final h?)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
              child: Text(h, style: AppText.footnote),
            ),
          DecoratedBox(
            decoration: _panel,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.panel),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rows of a group, the last one told it is last so it draws no
/// divider. A row only knows it is last once the group's rows are all known,
/// which for Gmail depends on how many inboxes there are.
List<Widget> _lastMarked(List<Widget> rows) => [
      for (var i = 0; i < rows.length; i++)
        switch (rows[i]) {
          final _SourceRow r when i == rows.length - 1 => r.asLast(),
          final _AddAccountRow r when i == rows.length - 1 => r.asLast(),
          final row => row,
        },
    ];

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.connection,
    required this.busy,
    required this.last,
    required this.onTap,
    this.title,
  });

  final _Source source;
  final Connection? connection;
  final bool busy;
  final bool last;
  final VoidCallback? onTap;

  /// In place of the source's name: a Gmail inbox's address.
  final String? title;

  _SourceRow asLast() => _SourceRow(
        source: source,
        connection: connection,
        busy: busy,
        last: true,
        onTap: onTap,
        title: title,
      );

  @override
  Widget build(BuildContext context) {
    final c = connection;
    final run = c?.latestRun;
    final problem = run?.problem;
    final reading = busy || (run?.isRunning ?? false);
    final done = c != null && !reading && problem == null;

    final (String line, Color tone) = switch (c) {
      null when busy => ('Connecting…', AppColors.label3),
      null => (source.note, AppColors.label3),
      _ when reading => ('Reading now…', AppColors.label3),
      _ when problem != null => (problem, AppColors.destructive),
      _ => _found(c),
    };

    return Column(
      children: [
        PressableRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                _BrandMark(source.provider),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          fontSize: 17,
                          height: 25.5 / 17,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          fontSize: 12.5,
                          height: 16 / 12.5,
                          color: tone,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (reading)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: AppColors.label3,
                    ),
                  )
                else if (done)
                  const Icon(Icons.check_circle, size: 21, color: AppColors.ok)
                else
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.label3,
                  ),
              ],
            ),
          ),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.separator,
            ),
          ),
      ],
    );
  }

  /// What a finished read found, in grey: the tick beside it is the only green
  /// on the row (Aryan, 2026-10-01).
  ///
  /// A Gmail inbox says what it held instead ("88 receipts · travel only"),
  /// which is what tells two inboxes apart at a glance.
  (String, Color) _found(Connection c) {
    final run = c.latestRun;
    if (run == null) return ('Connected', AppColors.label3);
    final receipts = c.receipts?.line();
    if (receipts != null) return (receipts, AppColors.label3);
    return switch (run.sufficiency) {
      Sufficiency.strong ||
      Sufficiency.moderate =>
        ('Read ${run.itemsFound} things', AppColors.label3),
      Sufficiency.weak => (
          'Only found ${run.itemsFound}. That may be too little to say much',
          AppColors.label3,
        ),
      _ => ('Nothing found here', AppColors.label3),
    };
  }
}

/// "Add another account", under the inboxes already connected.
class _AddAccountRow extends StatelessWidget {
  const _AddAccountRow({
    required this.busy,
    required this.onTap,
    this.last = false,
  });

  final bool busy;
  final VoidCallback? onTap;
  final bool last;

  _AddAccountRow asLast() => _AddAccountRow(busy: busy, onTap: onTap, last: true);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PressableRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.fill3,
                    borderRadius: BorderRadius.circular(8.4),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add, size: 20, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    busy ? 'Connecting…' : 'Add another account',
                    style: AppText.body.copyWith(
                      fontSize: 17,
                      height: 25.5 / 17,
                      color: busy ? AppColors.label3 : AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (busy)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: AppColors.label3,
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.label3,
                  ),
              ],
            ),
          ),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.separator,
            ),
          ),
      ],
    );
  }
}

/// Several apps' marks overlapping in one leading slot, for a group more than
/// one app fills (Music: YouTube, Spotify, Apple Music).
class _StackedMarks extends StatelessWidget {
  const _StackedMarks(this.apps);

  final List<SourceProvider> apps;

  static const _mark = 18.0;

  @override
  Widget build(BuildContext context) {
    // Spread to fit the 29pt slot whatever the count.
    final step =
        apps.length < 2 ? 0.0 : (29 - _mark) / (apps.length - 1);
    return SizedBox(
      width: 29,
      height: 29,
      child: Stack(
        children: [
          for (final (i, a) in apps.indexed)
            Positioned(
              left: i * step,
              top: i.isEven ? 0 : 29 - _mark,
              width: _mark,
              height: _mark,
              child: FittedBox(child: _BrandMark(a)),
            ),
        ],
      ),
    );
  }
}

/// The 30pt square in each source's own colour.
class _BrandMark extends StatelessWidget {
  const _BrandMark(this.provider);

  final SourceProvider provider;

  @override
  Widget build(BuildContext context) {
    final (Color back, Widget mark) = switch (provider) {
      SourceProvider.spotify => (
          BrandColors.spotify,
          const CustomPaint(size: Size(20, 20), painter: _SpotifyWaves()),
        ),
      SourceProvider.youtube => (
          BrandColors.youtube,
          const Icon(
            Icons.play_arrow_rounded,
            size: 20,
            color: AppColors.label,
          ),
        ),
      SourceProvider.netflix => (
          BrandColors.netflix,
          Text(
            'N',
            style: AppText.title3.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              height: 1,
            ),
          ),
        ),
      SourceProvider.gmail => (
          BrandColors.gmail,
          const Icon(
            Icons.mail_rounded,
            size: 18,
            color: BrandColors.gmailRed,
          ),
        ),
      SourceProvider.appleMusic => (
          BrandColors.appleMusic,
          const Icon(
            Icons.music_note_rounded,
            size: 19,
            color: AppColors.label,
          ),
        ),
      SourceProvider.instagram => (
          BrandColors.instagramVia,
          const Icon(
            Icons.camera_alt_outlined,
            size: 18,
            color: AppColors.label,
          ),
        ),
      SourceProvider.unknown => (
          AppColors.fill2,
          const Icon(Icons.link, size: 18, color: AppColors.label2),
        ),
    };
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: back,
        borderRadius: BorderRadius.circular(8.4),
        border: Border.all(color: BrandColors.edge),
      ),
      alignment: Alignment.center,
      child: mark,
    );
  }
}

/// Spotify's three arcs, which no icon font carries.
class _SpotifyWaves extends CustomPainter {
  const _SpotifyWaves();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.label
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    for (final (y, span, stroke) in [
      (h * 0.36, 0.56, 1.9),
      (h * 0.52, 0.46, 1.7),
      (h * 0.67, 0.36, 1.5),
    ]) {
      paint.strokeWidth = stroke;
      final path = Path()
        ..moveTo(w * (0.5 - span / 2), y)
        ..quadraticBezierTo(
          w / 2,
          y - h * 0.12,
          w * (0.5 + span / 2),
          y + h * 0.03,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SpotifyWaves oldDelegate) => false;
}

/// The plate every card and group on this screen sits on.
final _panel = BoxDecoration(
  color: AppColors.row,
  borderRadius: BorderRadius.circular(Radii.panel),
  border: Border.all(color: AppColors.hairline),
);
