import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/identity.dart';
import '../storage/token_store.dart';

/// How far through the app a person is.
///
/// The router reads this and nothing else to decide where someone belongs, so
/// there is one rule for the whole app rather than a guard on every screen.
enum SessionStage {
  /// Still reading the keychain. The splash holds here.
  unknown,

  /// No token.
  signedOut,

  /// Signed in, but the profile is not built yet.
  onboarding,

  /// Everything from here is the app proper.
  ready,
}

@immutable
class Session {
  const Session({
    this.stage = SessionStage.unknown,
    this.tier = VerificationTier.none,
    this.premium = false,
    this.paused = false,
  });

  final SessionStage stage;

  /// Chat is gated on this being anything but [VerificationTier.none] —
  /// either route opens it, and the gold tier unlocks nothing extra.
  final VerificationTier tier;

  final bool premium;
  final bool paused;

  bool get canChat => tier != VerificationTier.none;

  Session copyWith({
    SessionStage? stage,
    VerificationTier? tier,
    bool? premium,
    bool? paused,
  }) =>
      Session(
        stage: stage ?? this.stage,
        tier: tier ?? this.tier,
        premium: premium ?? this.premium,
        paused: paused ?? this.paused,
      );
}

class SessionController extends Notifier<Session> {
  @override
  Session build() {
    // Deliberately not awaited: the splash renders on [SessionStage.unknown]
    // and the router moves the moment this resolves.
    unawaited(_restore());
    return const Session();
  }

  Future<void> _restore() async {
    final token = await ref.read(tokenStoreProvider).readAccess();
    if (token == null) {
      state = state.copyWith(stage: SessionStage.signedOut);
      return;
    }
    // TODO(backend): GET /me and populate tier, premium, paused and whether
    // the profile is complete. Until then a stored token means a ready
    // account, which is what the prototype assumed.
    state = state.copyWith(stage: SessionStage.ready);
  }

  Future<void> onSignedIn({required bool profileComplete}) async {
    state = state.copyWith(
      stage: profileComplete ? SessionStage.ready : SessionStage.onboarding,
    );
  }

  void onProfileCreated() =>
      state = state.copyWith(stage: SessionStage.ready);

  void onVerified(VerificationTier tier) => state = state.copyWith(tier: tier);

  void onPremium({required bool active}) =>
      state = state.copyWith(premium: active);

  void onPaused({required bool paused}) =>
      state = state.copyWith(paused: paused);

  /// Sign-out, and the only correct response to a refused refresh.
  ///
  /// Tokens are cleared first: if the network call fails we still want the
  /// device to forget the session.
  Future<void> signOut() async {
    await ref.read(tokenStoreProvider).clear();
    state = const Session(stage: SessionStage.signedOut);
  }
}

final sessionProvider =
    NotifierProvider<SessionController, Session>(SessionController.new);

