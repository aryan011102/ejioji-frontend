import 'dart:async';

import 'package:ejioji/core/session/session.dart';
import 'package:ejioji/core/theme/app_theme.dart';
import 'package:ejioji/data/chat_repository.dart';
import 'package:ejioji/data/in_common_repository.dart';
import 'package:ejioji/data/live_events.dart';
import 'package:ejioji/data/providers.dart';
import 'package:ejioji/features/chats/presentation/conversation_page.dart';
import 'package:ejioji/shared/models/chat.dart';
import 'package:ejioji/shared/models/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = 'me-1';
const _them = 'them-2';

class _Session extends SessionController {
  @override
  Session build() => const Session(stage: SessionStage.ready, userId: _me);
}

class _Live implements LiveEvents {
  // Closed as each test ends.
  // ignore: close_sinks
  final out =StreamController<LiveEvent>.broadcast();

  @override
  Stream<LiveEvent> get events => out.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The server's side of one chat.
class _Server implements ChatRepository {
  _Server(this.held);

  final List<Message> held;

  /// Set, a read waits on it.
  Completer<void>? slow;

  @override
  Future<MessagePage> messages(
    String matchId, {
    int? after,
    int? before,
    int limit = 50,
  }) async {
    await slow?.future;
    return MessagePage(
      messages: [
        for (final m in held)
          if (after == null || m.seq > after) m,
      ],
      hasMore: false,
      myReadSeq: held.length,
      theirReadSeq: held.length,
    );
  }

  @override
  Future<int> markRead(String matchId, int seq) async => seq;

  @override
  Future<({int waiting, int cap})> gamesWaiting(String matchId) async =>
      (waiting: 0, cap: 5);

  @override
  Future<Message> startGame(
    String matchId, {
    required GameKind game,
    required String clientId,
    List<Object> cards = const [],
    List<int>? picks,
    List<String>? statements,
    int? lie,
    String? text,
    int? cell,
  }) async {
    final message = Message.fromJson(_flames(sender: _me));
    held.add(message);
    return message;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoRing implements InCommonRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, Object?> _flames({String sender = _them}) => {
      'id': 'm-1',
      'match_id': 'match',
      'seq': 1,
      'sender_id': sender,
      'client_id': 'c-1',
      'kind': 'game',
      'text': 'Played FLAMES.',
      'media': null,
      'tile': null,
      'sent_at': '2026-11-20T10:00:00Z',
      'game_event': 'started',
      'game': {
        'id': 'g-1',
        'game': 'flames',
        'title': 'FLAMES',
        'status': 'done',
        'started_by': sender,
        'cards': <Object?>[],
        'flames': {
          'names': ['Arjun', 'Priya'],
          'letter': 'M',
          'word': 'Marriage',
          'line': 'The cards have spoken.',
          'left': 6,
        },
      },
    };

/// FLAMES plays its working when it is the first thing said in a chat, as it
/// does anywhere else, and never just because the chat was opened.
void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('theonebytwo/screen_capture'),
      (_) async => null,
    );
  });

  Future<_Live> open(WidgetTester tester, _Server server) async {
    tester.view.devicePixelRatio = 1;
    // Wide enough for the test font, whose every letter is a square.
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    final live = _Live();
    addTearDown(live.out.close);
    final conversation = Conversation.fromJson({
      'match_id': 'match',
      'matched_at': '2026-11-20T10:00:00Z',
      'person': {'user_id': _them, 'first_name': 'Priya'},
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          chatRepositoryProvider.overrideWithValue(server),
          inCommonRepositoryProvider.overrideWithValue(_NoRing()),
          liveEventsProvider.overrideWith((ref) => live),
          conversationsProvider.overrideWith((ref) async => [conversation]),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const ConversationPage(threadId: 'match'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return live;
  }

  Future<void> playsThenTells(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('FLAMES · Marriage'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('FLAMES · Marriage'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  }

  Future<void> showsSettled(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('FLAMES · Marriage'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await tester.pumpAndSettle();
  }

  testWidgets('theirs, arriving live, plays', (tester) async {
    final live = await open(tester, _Server([]));
    live.out.add(
      LiveEvent('message.new', {'match_id': 'match', 'message': _flames()}),
    );
    await tester.pump();
    await playsThenTells(tester);
  });

  testWidgets('mine, from the games list, plays', (tester) async {
    await open(tester, _Server([]));
    await tester.tap(find.text('Play a game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FLAMES'));
    await tester.pump();
    // The list slides away as the working starts.
    await tester.pump(const Duration(milliseconds: 400));
    await playsThenTells(tester);
  });

  testWidgets('theirs, caught up on after a dropped socket, plays',
      (tester) async {
    final server = _Server([]);
    final live = await open(tester, server);
    server.held.add(Message.fromJson(_flames()));
    live.out.add(const LiveEvent(LiveEvent.resync, {}));
    await tester.pump();
    await playsThenTells(tester);
  });

  testWidgets('already there when the chat opens, does not play',
      (tester) async {
    await open(tester, _Server([Message.fromJson(_flames())]));
    await showsSettled(tester);
  });

  testWidgets('already there, the socket connecting mid load, does not play',
      (tester) async {
    final slow = Completer<void>();
    final server = _Server([Message.fromJson(_flames())])..slow = slow;
    final live = await open(tester, server);
    live.out.add(const LiveEvent(LiveEvent.resync, {}));
    await tester.pump();
    slow.complete();
    await tester.pump();
    await showsSettled(tester);
  });
}
