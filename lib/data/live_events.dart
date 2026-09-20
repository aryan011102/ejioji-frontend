import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../core/storage/token_store.dart';
import 'providers.dart';
import 'socket/app_socket.dart';

/// One event from the chat socket.
///
/// [type] is the server's (`message.new`, `messages.read`, `typing`,
/// `conversation.ended`, `request.new`, `match.new`), plus one of ours:
/// `resync`, sent every time the socket (re)opens, because the socket is a
/// live channel and not the record. Anything that shows server state refetches
/// on it.
@immutable
class LiveEvent {
  const LiveEvent(this.type, this.data);

  static const resync = 'resync';

  final String type;
  final Json data;

  String? get matchId => data.strOrNull('match_id');
}

/// The one socket per install that tells the app something changed.
///
/// It authenticates with the bearer header on the upgrade, like every other
/// call. When the server closes it with 4401 the access token has expired, so
/// one cheap authenticated call runs first (the API client refreshes on its
/// 401) and the socket reopens with the new token. 4000 means events were
/// lost: reopen, and the `resync` that follows does the catching up. Anything
/// else (the phone slept, the network changed) reopens with a backoff.
class LiveEvents {
  LiveEvents(this._tokens, this._api);

  final TokenStore _tokens;
  final ApiClient _api;

  final _events = StreamController<LiveEvent>.broadcast();
  AppSocket? _socket;
  Timer? _retry;
  bool _connecting = false;
  bool _disposed = false;
  int _failures = 0;

  Stream<LiveEvent> get events => _events.stream;

  void start() => unawaited(_connect());

  /// Tells the other person this one is typing. Best effort: nothing is lost
  /// if the socket is down.
  void typing(String matchId) {
    _socket?.add(jsonEncode({'type': 'typing', 'match_id': matchId}));
  }

  Future<void> _connect() async {
    // A browser build has no transport to open (data/socket/app_socket.dart).
    // Checked here rather than left to fail, so it does not sit in a retry loop
    // against something that will never exist.
    if (!socketsSupported) return;
    if (_disposed || _connecting || _socket != null) return;
    _connecting = true;
    try {
      final token = await _tokens.readAccess();
      if (token == null || _disposed) return;

      final base = Uri.parse(Env.apiBaseUrl);
      final url = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: Api.chatSocket,
      );
      final socket = await connectSocket(
        url.toString(),
        headers: {'Authorization': 'Bearer $token'},
        timeout: const Duration(seconds: 15),
        pingInterval: const Duration(seconds: 25),
      );
      if (_disposed) {
        await socket.close();
        return;
      }

      _socket = socket;
      _failures = 0;
      _events.add(const LiveEvent(LiveEvent.resync, {}));

      socket.listen(
        _onFrame,
        onDone: () => _onClosed(socket.closeCode),
        onError: (_) {},
      );
    } on SocketRefused {
      // The server refuses a bad or expired token before accepting, which
      // reaches the phone as a refused upgrade (HTTP 403), not as close code
      // 4401. Refresh through one authenticated call, then try again.
      if (await _refreshed()) {
        _scheduleRetry();
      }
    } on Object catch (e) {
      debugPrint('live: connect failed (${e.runtimeType})');
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  void _onFrame(Object? frame) {
    if (frame is! String) return;
    try {
      final decoded = jsonDecode(frame);
      if (decoded is! Map) return;
      final data = asJson(decoded);
      final type = data.strOrNull('type');
      if (type != null) _events.add(LiveEvent(type, data));
    } on Object {
      // A frame we cannot read is dropped; the next resync covers it.
    }
  }

  Future<void> _onClosed(int? code) async {
    _socket = null;
    if (_disposed) return;
    if (code == 4401) {
      if (await _refreshed()) unawaited(_connect());
      return;
    }
    if (code == 4000) {
      unawaited(_connect());
      return;
    }
    _scheduleRetry();
  }

  /// One cheap authenticated call, which the API client refreshes on a 401.
  /// False when the session is over: the client has already sent the person
  /// to sign in, and there is nothing to reopen.
  Future<bool> _refreshed() async {
    try {
      await _api.getJson(Api.me);
      return true;
    } on UnauthorisedFailure {
      return false;
    } on ApiException {
      // Offline or the server is down: worth another try later.
      return true;
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retry?.cancel();
    final seconds = [1, 2, 5, 10, 30][_failures.clamp(0, 4)];
    _failures++;
    _retry = Timer(Duration(seconds: seconds), () => unawaited(_connect()));
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    await _socket?.close();
    _socket = null;
    await _events.close();
  }
}

/// Alive while anything watches it: the tab shell watches it for as long as
/// someone is signed in and inside the app.
final liveEventsProvider = Provider.autoDispose<LiveEvents>((ref) {
  final live = LiveEvents(
    ref.watch(tokenStoreProvider),
    ref.watch(apiClientProvider),
  )..start();
  ref.onDispose(live.dispose);
  return live;
});
