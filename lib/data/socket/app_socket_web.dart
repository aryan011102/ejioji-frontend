/// The browser stub. There is no socket here, and nothing tries to open one.
///
/// A browser can open a WebSocket, but not with an Authorization header, which
/// is how this one authenticates (CLAUDE.md: the socket authenticates with the
/// bearer header on the upgrade). Moving the token into the URL would put an
/// access token in a query string, which is the one place it must not go. So the
/// web build has no live channel rather than a weaker-authenticated one.
///
/// Nothing is lost that matters for what the web build is for. The socket only
/// ever says "something changed": every screen fetches its own state over HTTP
/// and refetches on `resync`. A browser sees a chat that does not tick by
/// itself, not a chat that is wrong.
const socketsSupported = false;

/// Kept so both sides of the conditional import have the same names.
class SocketRefused implements Exception {
  const SocketRefused();
}

class AppSocket {
  int? get closeCode => null;

  void add(String frame) {}

  void listen(
    void Function(Object?) onData, {
    required void Function() onDone,
    required void Function(Object) onError,
  }) {}

  Future<void> close() async {}
}

Future<AppSocket> connectSocket(
  String url, {
  required Map<String, String> headers,
  required Duration timeout,
  required Duration pingInterval,
}) async {
  // Unreachable: LiveEvents checks socketsSupported before it calls this. If
  // that check is ever removed, this refuses rather than opening anything.
  throw const SocketRefused();
}
