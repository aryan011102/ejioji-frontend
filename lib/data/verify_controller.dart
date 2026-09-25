import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/network/api_exception.dart';
import 'providers.dart';
import 'verification_repository.dart';

/// The DigiLocker handoff, the same shape as a Google connect
/// ([ConnectController]):
///
/// - **DigiLocker's page opens in the system browser, never a WebView.** A
///   WebView we control could read the Aadhaar-linked number and PIN typed into
///   it, and imitating a government login inside our own chrome is what a
///   phishing app does.
/// - **The app finishes with its own bearer token**, and ignores any redirect
///   carrying a state it did not start. The state is bound to this person on
///   the server, so finishing someone else's would verify the wrong account.
class VerifyController extends Notifier<bool> {
  /// Long enough to sign in to DigiLocker with an OTP and read its consent
  /// screen, short enough that a forgotten tab does not hold the app forever.
  static const _window = Duration(minutes: 5);

  AppLinks? _links;

  @override
  bool build() {
    ref.onDispose(() => _links = null);
    return false;
  }

  /// Runs the whole check. Null means the person came back without finishing:
  /// closed the tab, or took too long. Nothing was shared or kept.
  Future<VerificationResult?> begin() async {
    if (state) return null;
    state = true;
    try {
      final repo = ref.read(verificationRepositoryProvider);
      final authorization = await repo.authorize();

      // Listen before opening the browser: a fast redirect can land before
      // the launch returns.
      final redirect = _nextRedirect(authorization.state);
      final opened = await launchUrl(
        Uri.parse(authorization.url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw const UnknownFailure(
          debugDetail: 'no browser would open DigiLocker',
        );
      }

      final link = await redirect;
      if (link == null) return null;

      final result = await repo.complete(
        state: authorization.state,
        code: link.queryParameters['code'],
        error: link.queryParameters['error'],
      );
      ref
        ..invalidate(verificationProvider)
        ..invalidate(myProfileProvider);
      return result;
    } finally {
      state = false;
    }
  }

  Future<Uri?> _nextRedirect(String expectedState) async {
    final links = _links ??= AppLinks();
    try {
      return await links.uriLinkStream
          .firstWhere(
            (uri) =>
                uri.path.startsWith('/oauth/digilocker') &&
                uri.queryParameters['state'] == expectedState,
          )
          .timeout(_window);
    } on TimeoutException {
      return null;
    }
  }
}

final verifyProvider =
    NotifierProvider<VerifyController, bool>(VerifyController.new);
