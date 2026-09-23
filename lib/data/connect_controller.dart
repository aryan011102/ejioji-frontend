import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/native/apple_music_kit.dart';
import '../core/network/api_exception.dart';
import '../shared/models/connection.dart';
import '../shared/models/enums.dart';
import 'providers.dart';

/// The OAuth handoff.
///
/// Three things happen here, in one place because they only make sense
/// together: the server issues a URL, the person answers on the provider's own
/// page, and the answer comes back to the app as a link.
///
/// Two decisions worth stating:
///
/// - **The consent page opens in the system browser, never a WebView.** A
///   WebView we control can read what is typed into it. Putting somebody's
///   Google password behind glass we own is exactly the thing this product
///   must never do, and Google refuses OAuth in embedded webviews anyway.
/// - **The app completes the flow with its own bearer token.** The redirect
///   carries a `state` the server bound to this user and this source, and the
///   completion is an authenticated call. A callback anyone could complete
///   would let an attacker have a victim finish the attacker's flow, pouring
///   the victim's data into the attacker's profile.
class ConnectController extends Notifier<SourceProvider?> {
  /// Long enough for a person to sign in, pick an account and read a consent
  /// screen, and short enough that a forgotten tab does not hold the app in a
  /// connecting state forever.
  static const _window = Duration(minutes: 5);

  AppLinks? _links;

  @override
  SourceProvider? build() {
    ref.onDispose(() => _links = null);
    return null;
  }

  /// Runs the whole handoff, and returns the run it opened.
  ///
  /// Returns null when the person declined on the provider's screen, which is
  /// an answer rather than a failure: the source is left unconnected and is
  /// not asked about again in this session.
  Future<IngestionRun?> begin(SourceProvider provider) async {
    if (state != null) return null;
    state = provider;

    try {
      final sources = ref.read(sourcesRepositoryProvider);
      if (provider == SourceProvider.appleMusic) return await _appleMusic();
      final authorization = await sources.authorize(provider);

      // Start listening before opening the browser. On a fast redirect the
      // link can arrive before an await on the launch returns.
      final redirect = _nextRedirect(authorization.state);

      final opened = await launchUrl(
        Uri.parse(authorization.url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw const UnknownFailure(
          debugDetail: 'no browser would open the consent page',
        );
      }

      final link = await redirect;
      if (link == null) {
        // They came back without finishing: closed the tab, or took too long.
        // Nothing was granted and nothing was read.
        return null;
      }

      final code = link.queryParameters['code'];
      final error = link.queryParameters['error'];

      final result = await sources.complete(
        provider,
        code: code,
        state: authorization.state,
        error: error,
      );

      if (result.declined) return null;

      ref.invalidate(connectionsProvider);
      return result.run;
    } finally {
      state = null;
    }
  }

  /// Apple Music has no browser and no redirect. Apple's own prompt appears
  /// over the app, and MusicKit hands back a token for the server to read the
  /// library with once. Apple offers no way for us to end that token, which
  /// the notice says, along with how the person can end it themselves.
  Future<IngestionRun?> _appleMusic() async {
    final sources = ref.read(sourcesRepositoryProvider);
    final developerToken = await sources.appleMusicDeveloperToken();

    final String userToken;
    try {
      userToken = await AppleMusicKit.userToken(developerToken);
    } on AppleMusicDenied catch (e) {
      if (!e.inSettings) return null;
      throw const ValidationFailure(
        'Apple Music access is off for theonebytwo. Turn it on in Settings, '
        'under Privacy & Security, Media & Apple Music, then try again.',
        code: 'apple_music_denied',
      );
    } on AppleMusicUnavailable catch (e) {
      throw ValidationFailure(
        'Apple Music did not answer. Check this phone is signed in to Apple '
        'Music, then try again.',
        code: 'apple_music_unavailable:${e.reason}',
      );
    }

    final result = await sources.completeAppleMusic(userToken: userToken);
    if (result.declined) return null;
    ref.invalidate(connectionsProvider);
    return result.run;
  }

  /// Waits for the redirect that belongs to this attempt.
  ///
  /// Links carrying somebody else's `state` are ignored rather than completed:
  /// the state is single use and bound to one user and one source, and
  /// handing the server a state we did not start is how a flow gets hijacked.
  Future<Uri?> _nextRedirect(String expectedState) async {
    final links = _links ??= AppLinks();
    try {
      return await links.uriLinkStream
          .firstWhere((uri) => uri.queryParameters['state'] == expectedState)
          .timeout(_window);
    } on TimeoutException {
      return null;
    }
  }
}

final connectProvider =
    NotifierProvider<ConnectController, SourceProvider?>(ConnectController.new);
