import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/ids.dart';
import '../../../data/live_events.dart';
import '../../../data/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/person.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// One conversation, from the server.
///
/// The messages come from the API; the socket only says that something
/// changed. Every time the socket (re)opens the page asks for everything after
/// the highest number it holds, so a message that arrived while the phone was
/// asleep is never skipped. Sends are optimistic and idempotent: the bubble
/// shows at once, and a retry reuses its client id, so a lost response never
/// becomes a second message.
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({required this.threadId, super.key});

  /// The match id. A conversation has no id of its own.
  final String threadId;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

/// A message this phone has sent and the server has not answered yet.
class _Pending {
  _Pending({required this.clientId, this.text, this.photo = false});

  final String clientId;
  final String? text;
  final bool photo;
  String? mediaId;
  bool failed = false;
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _composer = TextEditingController();
  final _picker = ImagePicker();

  final _messages = <Message>[];
  final _pending = <_Pending>[];
  StreamSubscription<LiveEvent>? _events;

  Object? _loadError;
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingOlder = false;
  bool _ended = false;
  int _myRead = 0;
  int _theirRead = 0;
  bool _theyTyping = false;
  Timer? _typingClear;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  String get _matchId => widget.threadId;
  String? get _me => ref.read(sessionProvider).userId;

  @override
  void initState() {
    super.initState();
    _events = ref.read(liveEventsProvider).events.listen(_onEvent);
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _typingClear?.cancel();
    _composer.dispose();
    super.dispose();
  }

  // Reading.

  Future<void> _load() async {
    try {
      final page = await ref.read(chatRepositoryProvider).messages(_matchId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _hasMore = page.hasMore;
        _myRead = page.myReadSeq;
        _theirRead = page.theirReadSeq;
        _loading = false;
        _loadError = null;
      });
      unawaited(_markRead());
    } on NotFoundFailure {
      if (mounted) {
        setState(() {
          _ended = true;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
    }
  }

  /// Everything after the highest number held. Run on every (re)connect.
  Future<void> _catchUp() async {
    if (_messages.isEmpty) return _load();
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .messages(_matchId, after: _messages.last.seq);
      if (!mounted) return;
      _merge(page.messages);
      setState(() => _theirRead = page.theirReadSeq);
      unawaited(_markRead());
    } on NotFoundFailure {
      if (mounted) setState(() => _ended = true);
    } on ApiException {
      // The next resync tries again.
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .messages(_matchId, before: _messages.first.seq);
      if (!mounted) return;
      _merge(page.messages);
      setState(() => _hasMore = page.hasMore);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  /// Adds messages not already held, keeps the list in sequence order, and
  /// drops the pending bubble each one answers.
  void _merge(Iterable<Message> incoming) {
    final held = {for (final m in _messages) m.id};
    final fresh = incoming.where((m) => !held.contains(m.id)).toList();
    if (fresh.isEmpty) return;
    final answered = {for (final m in fresh) m.clientId};
    setState(() {
      _messages
        ..addAll(fresh)
        ..sort((a, b) => a.seq.compareTo(b.seq));
      _pending.removeWhere((p) => answered.contains(p.clientId));
    });
  }

  Future<void> _markRead() async {
    final me = _me;
    final theirs = _messages.where((m) => me != null && !m.mine(me));
    if (theirs.isEmpty) return;
    final top = theirs.last.seq;
    if (top <= _myRead) return;
    _myRead = top;
    try {
      await ref.read(chatRepositoryProvider).markRead(_matchId, top);
      ref.invalidate(conversationsProvider);
    } on ApiException {
      // Unread stays unread; nothing else depends on it.
    }
  }

  void _onEvent(LiveEvent event) {
    if (event.type == LiveEvent.resync) {
      unawaited(_catchUp());
      return;
    }
    if (event.matchId != _matchId) return;
    switch (event.type) {
      case 'message.new':
        final raw = event.data.objectOrNull('message');
        if (raw == null) return;
        _merge([Message.fromJson(raw)]);
        setState(() => _theyTyping = false);
        unawaited(_markRead());
      case 'messages.read':
        setState(() => _theirRead = event.data.intOr('read_seq', _theirRead));
      case 'typing':
        _typingClear?.cancel();
        setState(() => _theyTyping = true);
        _typingClear = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _theyTyping = false);
        });
      case 'conversation.ended':
        setState(() => _ended = true);
    }
  }

  // Writing.

  void _onComposerChanged(String _) {
    setState(() {});
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) > const Duration(seconds: 3)) {
      _lastTypingSent = now;
      ref.read(liveEventsProvider).typing(_matchId);
    }
  }

  Future<void> _sendText() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _ended) return;
    _composer.clear();
    final pending = _Pending(clientId: Ids.uuid(), text: text);
    setState(() => _pending.add(pending));
    await _deliver(pending);
  }

  Future<void> _sendPhoto() async {
    if (_ended) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;
    final pending = _Pending(clientId: Ids.uuid(), photo: true);
    setState(() => _pending.add(pending));
    try {
      final asset = await ref.read(mediaRepositoryProvider).uploadToChat(
            matchId: _matchId,
            bytes: await picked.readAsBytes(),
            kind: MediaKind.photo,
          );
      pending.mediaId = asset.id;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _pending.remove(pending));
      showAppToast(context, e.message);
      return;
    }
    await _deliver(pending);
  }

  /// Sends, or re-sends with the same client id. The server keys on it, so a
  /// retry after a lost response is the same message, not a second one.
  Future<void> _deliver(_Pending pending) async {
    setState(() => pending.failed = false);
    try {
      final message = await ref.read(chatRepositoryProvider).send(
            _matchId,
            text: pending.text,
            mediaId: pending.mediaId,
            clientId: pending.clientId,
          );
      if (!mounted) return;
      _merge([message]);
      ref.invalidate(conversationsProvider);
    } on NotFoundFailure {
      if (!mounted) return;
      setState(() {
        _pending.remove(pending);
        _ended = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => pending.failed = true);
      showAppToast(context, e.message);
    }
  }

  // The menu.

  Person? get _person => ref
      .read(conversationsProvider)
      .valueOrNull
      ?.where((c) => c.matchId == _matchId)
      .firstOrNull
      ?.person;

  Future<void> _menu() async {
    final person = _person;
    final name = person?.firstName ?? 'them';
    final choice = await showAppActionSheet(
      context,
      message: '$name is never told if you report them.',
      actions: [
        const SheetAction(
          'Ready for friends and family',
          icon: Icons.people_alt_rounded,
        ),
        const SheetAction('Unmatch', destructive: true),
        const SheetAction('Report', destructive: true),
        SheetAction('Block $name', destructive: true),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 0:
        showAppToast(context, 'Sharing with friends and family is coming soon.');
      case 1:
        await _unmatch(name);
      case 2:
        if (person == null) return;
        unawaited(
          context.push<void>(
            Routes.reportFor(
              person.userId,
              name: person.firstName,
              matchId: _matchId,
            ),
          ),
        );
      case 3:
        if (person != null) await _block(person.userId, name);
    }
  }

  Future<void> _unmatch(String name) async {
    final choice = await showAppActionSheet(
      context,
      title: 'Unmatch $name?',
      message: 'The chat closes for both of you and cannot be reopened. You '
          'will not be shown to each other again.',
      actions: const [SheetAction('Unmatch', destructive: true)],
    );
    if (choice != 0 || !mounted) return;
    try {
      await ref.read(matchingRepositoryProvider).unmatch(_matchId);
      if (!mounted) return;
      ref
        ..invalidate(conversationsProvider)
        ..invalidate(matchesProvider);
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  Future<void> _block(String userId, String name) async {
    final choice = await showAppActionSheet(
      context,
      title: 'Block $name?',
      message: 'The chat closes, and they can no longer find you or write to '
          'you. They are not told.',
      actions: const [SheetAction('Block', destructive: true)],
    );
    if (choice != 0 || !mounted) return;
    try {
      await ref.read(matchingRepositoryProvider).block(userId);
      if (!mounted) return;
      ref
        ..invalidate(conversationsProvider)
        ..invalidate(matchesProvider)
        ..invalidate(blockedProvider);
      showAppToast(context, '$name is blocked.');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  // Drawing.

  @override
  Widget build(BuildContext context) {
    // Watched so the socket and the name stay available while this is open.
    ref
      ..watch(liveEventsProvider)
      ..watch(conversationsProvider);
    final name = _person?.displayName ?? 'Chat';

    return AppScaffold(
      navBar: AppNavBar(
        title: name,
        backLabel: 'Chats',
        onBack: () => context.pop(),
        trailingLabel: _ended ? null : '···',
        onTrailing: _ended ? null : _menu,
      ),
      footer: _ended ? _endedNote() : _composerBar(),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    final error = _loadError;
    if (error != null) {
      return ErrorView(
        error: error,
        onRetry: () {
          setState(() => _loading = true);
          unawaited(_load());
        },
      );
    }

    final me = _me;
    final myLatestRead = _messages
        .where((m) => me != null && m.mine(me) && m.seq <= _theirRead)
        .map((m) => m.seq)
        .fold<int?>(null, (a, b) => a == null || b > a ? b : a);

    // Newest at the bottom, and the list starts there: reversed, so the
    // children below run newest first.
    final rows = <Widget>[
      if (_theyTyping)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('typing…', style: AppText.micro),
        ),
      for (final p in _pending.reversed) _PendingBubble(pending: p, onRetry: _deliver),
    ];
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      rows.add(
        _Bubble(
          message: m,
          mine: me != null && m.mine(me),
          read: m.seq == myLatestRead,
        ),
      );
      final older = i > 0 ? _messages[i - 1] : null;
      if (older == null ||
          dayLabel(older.sentAt.toLocal()) != dayLabel(m.sentAt.toLocal())) {
        rows.add(
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(dayLabel(m.sentAt.toLocal()), style: AppText.micro),
            ),
          ),
        );
      }
    }
    if (_hasMore) {
      rows.add(
        Center(
          child: TextButton(
            onPressed: _loadingOlder ? null : _loadOlder,
            child: Text(_loadingOlder ? 'Loading…' : 'Earlier messages'),
          ),
        ),
      );
    }
    rows.add(
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: NoteCard(
          icon: Icons.shield_outlined,
          text: 'Keep it in the app for now. Nobody from theonebytwo will ever '
              'ask for money, documents or an OTP. Report anyone who does.',
        ),
      ),
    );

    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 12, Insets.gutter, 16),
      children: rows,
    );
  }

  Widget _endedNote() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'This conversation has ended.',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      );

  Widget _composerBar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: AppColors.hairline),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Pressable(
          onTap: _sendPhoto,
          semanticLabel: 'Send a photo',
          child: const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Icon(Icons.add_circle_outline, color: AppColors.accent),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
            child: TextField(
              controller: _composer,
              maxLines: null,
              // Bounded so a paste cannot push an unbounded payload at the API.
              maxLength: 2000,
              style: AppText.body.copyWith(fontSize: 15.5),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Message',
                hintStyle: AppText.body.copyWith(color: AppColors.label3),
                filled: true,
                fillColor: AppColors.row,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
              onChanged: _onComposerChanged,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Pressable(
          onTap: _composer.text.trim().isEmpty ? null : _sendText,
          semanticLabel: 'Send',
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _composer.text.trim().isEmpty
                  ? AppColors.fill2
                  : AppColors.fill,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_upward,
              size: 20,
              color: AppColors.onAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.read});

  final Message message;
  final bool mine;

  /// Set on my most recent message they have read, and only that one.
  final bool read;

  @override
  Widget build(BuildContext context) {
    final media = message.media;
    final time = clockTime(message.sentAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (media != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 220,
                      child: AspectRatio(
                        aspectRatio: media.aspectRatio.clamp(0.5, 2.0),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(media.stillUrl, fit: BoxFit.cover),
                            if (message.kind == MessageKind.video)
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 44,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (message.text != null && message.text!.isNotEmpty) ...[
                  if (media != null) const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: mine ? AppColors.fill : AppColors.bubbleThem,
                      borderRadius: BorderRadius.circular(20),
                      border: mine ? null : Border.all(color: AppColors.bubbleThemEdge),
                    ),
                    child: Text(
                      message.text!,
                      style: AppText.body.copyWith(
                        fontSize: 15.5,
                        height: 21 / 15.5,
                        color: mine ? AppColors.onAccent : AppColors.label,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  mine && read ? '$time · Read' : time,
                  style: AppText.micro.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  const _PendingBubble({required this.pending, required this.onRetry});

  final _Pending pending;
  final Future<void> Function(_Pending) onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Pressable(
              onTap: pending.failed ? () => onRetry(pending) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Opacity(
                    opacity: 0.6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.fill,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pending.photo ? 'Photo' : pending.text ?? '',
                        style: AppText.body.copyWith(
                          fontSize: 15.5,
                          color: AppColors.onAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pending.failed ? 'Not sent · tap to try again' : 'Sending…',
                    style: AppText.micro.copyWith(
                      fontSize: 11,
                      color: pending.failed ? AppColors.destructive : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
