import 'dart:io';

/// The real transport, everywhere Dart has `dart:io`: both phones, and desktop.
const socketsSupported = true;

/// The server refused the upgrade.
///
/// It refuses a bad or expired token before accepting, which arrives as an HTTP
/// 403 rather than as a close code, so it is an exception rather than a close.
class SocketRefused implements Exception {
  const SocketRefused();
}

/// The slice of a socket this app uses, so the web stub has a small surface to
/// stand in for and `LiveEvents` never names `dart:io` itself.
class AppSocket {
  AppSocket(this._socket);

  final WebSocket _socket;

  int? get closeCode => _socket.closeCode;

  void add(String frame) => _socket.add(frame);

  void listen(
    void Function(Object?) onData, {
    required void Function() onDone,
    required void Function(Object) onError,
  }) {
    _socket.listen(onData, onDone: onDone, onError: onError, cancelOnError: false);
  }

  Future<void> close() => _socket.close();
}

Future<AppSocket> connectSocket(
  String url, {
  required Map<String, String> headers,
  required Duration timeout,
  required Duration pingInterval,
}) async {
  try {
    // The AppSocket returned here owns it, and LiveEvents closes that in its
    // dispose. The lint cannot see through the wrapper.
    // ignore: close_sinks
    final socket = await WebSocket.connect(url, headers: headers).timeout(timeout);
    socket.pingInterval = pingInterval;
    return AppSocket(socket);
  } on WebSocketException {
    throw const SocketRefused();
  }
}
