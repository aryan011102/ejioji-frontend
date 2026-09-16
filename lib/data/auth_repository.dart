import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../core/storage/device.dart';
import '../core/storage/token_store.dart';

/// What the server says after a code is requested.
///
/// It deliberately says nothing about whether the number already has an
/// account: that would turn the sign-in screen into a "is this person on a
/// matrimonial app" lookup for anyone holding a phone book.
@immutable
class OtpChallenge {
  const OtpChallenge({
    required this.expiresIn,
    required this.retryAfter,
    this.debugCode,
  });

  final Duration expiresIn;

  /// How long until another code can be asked for, so the Resend button can
  /// count down rather than fail.
  final Duration retryAfter;

  /// Only ever set outside deployed environments, so local development does
  /// not need a real SMS provider. Never populated in staging or production.
  final String? debugCode;

  static OtpChallenge fromJson(Json j) => OtpChallenge(
        expiresIn: Duration(seconds: j.intOr('expires_in_seconds', 300)),
        retryAfter: Duration(seconds: j.intOr('retry_after_seconds', 60)),
        debugCode: j.strOrNull('debug_code'),
      );
}

@immutable
class SignedIn {
  const SignedIn({required this.userId, required this.isNewUser});

  final String userId;

  /// True only on the call that created the account. It is a routing hint,
  /// not a profile check: the profile is still read before deciding where to
  /// send someone.
  final bool isNewUser;
}

/// The account behind the token.
@immutable
class Me {
  const Me({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdAt,
    this.phoneVerifiedAt,
  });

  final String id;
  final String phone;
  final String status;
  final DateTime? phoneVerifiedAt;
  final DateTime createdAt;

  bool get isActive => status == 'active';

  static Me fromJson(Json j) => Me(
        id: j.str('id'),
        phone: j.str('phone_e164'),
        status: j.str('status'),
        phoneVerifiedAt: j.timeOrNull('phone_verified_at'),
        createdAt: j.time('created_at'),
      );
}

class AuthRepository {
  const AuthRepository(this._api, this._tokens, this._device);

  final ApiClient _api;
  final TokenStore _tokens;
  final DeviceIdentity _device;

  /// Sends a code. The phone goes up in whatever form the field produced; the
  /// server is the one that normalises it.
  Future<OtpChallenge> requestCode(String phone) async {
    final body = await _api.post(
      Api.otpStart,
      body: {
        'phone': phone,
        'device_key': await _device.key(),
        'platform': DeviceIdentity.platform,
      },
    );
    return OtpChallenge.fromJson(body);
  }

  /// Verifies, and stores the pair. Tokens are written before this returns,
  /// so anything that runs after it is already authenticated.
  Future<SignedIn> verifyCode({
    required String phone,
    required String code,
  }) async {
    final body = await _api.post(
      Api.otpVerify,
      body: {
        'phone': phone,
        'code': code,
        'device_key': await _device.key(),
        'platform': DeviceIdentity.platform,
      },
    );

    final tokens = body.object('tokens');
    await _tokens.save(
      access: tokens.str('access_token'),
      refresh: tokens.str('refresh_token'),
    );

    return SignedIn(
      userId: body.str('user_id'),
      isNewUser: body.flag('is_new_user'),
    );
  }

  Future<Me> me() async => Me.fromJson(await _api.getJson(Api.me));

  /// Signs out every device. The local tokens are cleared whatever the server
  /// says, because a failed call must still leave this phone signed out.
  Future<void> signOut() async {
    try {
      await _api.postEmpty(Api.logout);
    } finally {
      await _tokens.clear();
    }
  }

  /// Immediate and final. There is no grace period and no undo, so the caller
  /// must have made that clear before getting here.
  ///
  /// The confirmation is the literal word, typed by the person.
  Future<void> deleteAccount({required String confirmation}) async {
    try {
      await _api.postEmpty(
        Api.deleteAccount,
        body: {'confirm': confirmation},
      );
    } finally {
      await _tokens.clear();
    }
  }

  /// Registering a token anywhere clears it from every other account, so a
  /// phone that changed hands stops receiving the last person's pushes.
  Future<void> registerPushToken(String token) async {
    await _api.putEmpty(
      Api.pushToken,
      body: {'device_key': await _device.key(), 'token': token},
    );
  }

  Future<void> clearPushToken() async {
    await _api.postEmpty(
      Api.pushTokenClear,
      body: {'device_key': await _device.key()},
    );
  }
}
