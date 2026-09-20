/// The chat socket's transport, chosen at compile time.
///
/// `dart:io` does not exist on the web, and an import of it is a compile error
/// there whether or not the code runs. So the one file that opens a socket picks
/// its implementation here: the real one everywhere Dart has `dart:io`, and a
/// refusing stub in a browser.
///
/// The browser build is for looking at screens, not for using the app: Chrome is
/// the only way to see the iOS layout on a machine without a Mac. Everything the
/// socket carries is a live update on top of state the app also fetches over
/// HTTP, so a browser sees a chat that does not tick, never a chat that is
/// wrong. [socketsSupported] is what `LiveEvents` checks so it does not sit in a
/// retry loop against a transport that will never exist.
library;

export 'app_socket_web.dart' if (dart.library.io) 'app_socket_io.dart';
