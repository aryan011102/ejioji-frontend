import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../push/push.dart';

/// Why a Firebase code could not be sent or checked, in words for the person.
class PhoneCodeFailure implements Exception {
  const PhoneCodeFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Firebase phone sign-in: Google sends the SMS and checks the code.
///
/// Used while the server says `firebase` (GET /auth/methods), the bridge until
/// our own SMS is registered with DLT. Firebase's own session is thrown away as
/// soon as we have its ID token: the only session this app keeps is ours, which
/// the server issues in exchange for that token.
///
/// Firebase is started once by [Push.init], with the same project, so this
/// works only in a build that has the Firebase defines.
abstract final class FirebasePhone {
  static int? _resendToken;

  /// Sends a code to [e164] and returns Firebase's id for this attempt, which
  /// [idToken] needs along with the code.
  static Future<String> send(String e164) {
    if (!Push.ready) {
      return Future.error(
        const PhoneCodeFailure('Signing in is not available right now.'),
      );
    }
    final sent = Completer<String>();
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: e164,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      codeSent: (verificationId, resendToken) {
        _resendToken = resendToken;
        if (!sent.isCompleted) sent.complete(verificationId);
      },
      verificationFailed: (e) {
        if (!sent.isCompleted) sent.completeError(PhoneCodeFailure(_say(e)));
      },
      // Android can read the SMS itself. The person still types the code (or
      // it is filled for them) on the next screen, so nothing happens here.
      verificationCompleted: (_) {},
      codeAutoRetrievalTimeout: (_) {},
    );
    return sent.future;
  }

  /// Checks [code] with Firebase and returns the ID token to hand our server.
  static Future<String> idToken({
    required String verificationId,
    required String code,
  }) async {
    try {
      final signedIn = await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ),
      );
      final token = await signedIn.user?.getIdToken();
      if (token == null) {
        throw const PhoneCodeFailure('That did not work. Try again.');
      }
      return token;
    } on FirebaseAuthException catch (e) {
      throw PhoneCodeFailure(_say(e));
    } finally {
      // Our session is the one that counts; Firebase's is not kept.
      unawaited(FirebaseAuth.instance.signOut().catchError((Object _) {}));
    }
  }

  static String _say(FirebaseAuthException e) {
    debugPrint('Firebase phone: ${e.code}');
    return switch (e.code) {
      'invalid-verification-code' => "That code isn't right.",
      'session-expired' || 'code-expired' =>
        'That code has expired. Send a new one.',
      'invalid-phone-number' => "That number doesn't look right.",
      'too-many-requests' || 'quota-exceeded' =>
        'Too many tries. Try again later.',
      'network-request-failed' => "Couldn't connect. Try again.",
      _ => 'That did not work. Try again.',
    };
  }
}
