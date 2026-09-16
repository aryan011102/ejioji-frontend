import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../shared/models/profile.dart';
import '../network/api_exception.dart';
import '../storage/token_store.dart';

/// How far through the app a person is.
///
/// The router reads this and nothing else to decide where someone belongs, so
/// there is one rule for the whole app rather than a guard on every screen.
enum SessionStage {
  /// Still reading the keychain and asking the server who this is. The splash
  /// holds here.
  unknown,

  /// No token, or a token the server refused.
  signedOut,

  /// Signed in, but there is no profile yet.
  onboarding,

  /// Everything from here is the app proper.
  ready,
}

@immutable
class Session {
  const Session({
    this.stage = SessionStage.unknown,
    this.userId,
    this.publish,
  });

  final SessionStage stage;

  /// Needed to tell your own messages from theirs, which the API expresses as
  /// a sender id rather than a flag.
  final String? userId;

  /// Whether the profile is out there, and what is stopping it if not. Null
  /// until the profile has been read once.
  ///
  /// `visible` is derived by the server on every read rather than stored: a
  /// consent withdrawal can empty a profile without the person touching
  /// anything, and when it does the profile has to stop showing on its own.
  final PublishState? publish;

  bool get isSignedIn =>
      stage == SessionStage.onboarding || stage == SessionStage.ready;

  /// Browsing is allowed before publishing. Appearing to others is not, which
  /// is the gate the other way round.
  bool get isVisible => publish?.visible ?? false;

  bool get isUnderReview => publish?.underReview ?? false;

  /// Taking a break is unpublishing: someone who could be out there and has
  /// chosen not to be.
  ///
  /// It is derived rather than stored, so it cannot disagree with the server.
  /// A profile that stopped showing because it fell below the bar is not
  /// paused, it is incomplete, and those two need different copy.
  bool get isPaused {
    final p = publish;
    return p != null && !p.published && p.canPublish;
  }

  Session copyWith({
    SessionStage? stage,
    String? userId,
    PublishState? publish,
  }) =>
      Session(
        stage: stage ?? this.stage,
        userId: userId ?? this.userId,
        publish: publish ?? this.publish,
      );
}

class SessionController extends Notifier<Session> {
  @override
  Session build() {
    // Deliberately not awaited: the splash renders on [SessionStage.unknown]
    // and the router moves the moment this resolves.
    unawaited(restore());
    return const Session();
  }

  /// Works out where this person belongs, from the token and the server.
  ///
  /// A stored token is not enough on its own: it may belong to an account that
  /// has since been erased or suspended, and it says nothing about whether a
  /// profile exists. Both questions are asked before anyone is let in.
  Future<void> restore() async {
    final token = await ref.read(tokenStoreProvider).readAccess();
    if (token == null) {
      state = const Session(stage: SessionStage.signedOut);
      return;
    }

    try {
      final me = await ref.read(authRepositoryProvider).me();
      if (!me.isActive) {
        await onSessionLost();
        return;
      }
      await _readProfile(userId: me.id);
    } on UnauthorisedFailure {
      // The refresh was already tried and refused by the interceptor. The
      // account may also have been erased, which reads the same way.
      await onSessionLost();
    } on ApiException {
      // Offline, or the server is down. Neither means signed out, and
      // clearing the token here would sign people out every time a train
      // went into a tunnel. Hold on the splash and let them retry.
      state = state.copyWith(stage: SessionStage.unknown);
    }
  }

  /// Called after a successful sign-in.
  ///
  /// The profile decides where to go, not the `is_new_user` flag: someone who
  /// started onboarding on another device and came back is not new, but is
  /// also not finished.
  Future<void> onSignedIn({required String userId}) =>
      _readProfile(userId: userId);

  Future<void> _readProfile({required String userId}) async {
    final profile = await ref.read(profileRepositoryProvider).load();
    state = Session(
      stage: profile.isComplete ? SessionStage.ready : SessionStage.onboarding,
      userId: userId,
      publish: profile.publish,
    );
  }

  /// Called by anything that has just changed the profile, so the router and
  /// the account screen agree with the server again.
  void onProfileChanged(MyProfile profile) {
    state = Session(
      stage: profile.isComplete ? SessionStage.ready : SessionStage.onboarding,
      userId: state.userId,
      publish: profile.publish,
    );
  }

  void onPublishChanged(PublishState publish) =>
      state = state.copyWith(publish: publish);

  /// The only correct response to a refused refresh. The client calls this;
  /// it does not navigate itself.
  Future<void> onSessionLost() async {
    await ref.read(tokenStoreProvider).clear();
    state = const Session(stage: SessionStage.signedOut);
  }

  /// Signs out everywhere, and forgets the push token first so this phone
  /// stops receiving someone else's names.
  ///
  /// Tokens are cleared whatever happens: if the network call fails we still
  /// want the device to forget the session.
  Future<void> signOut() async {
    final auth = ref.read(authRepositoryProvider);
    try {
      await auth.clearPushToken();
    } on ApiException {
      // Best effort. Signing out must not fail because a push token could not
      // be cleared.
    }
    try {
      await auth.signOut();
    } on ApiException {
      // Same: the device forgets the session either way.
    } finally {
      await ref.read(tokenStoreProvider).clear();
      state = const Session(stage: SessionStage.signedOut);
    }
  }
}

final sessionProvider =
    NotifierProvider<SessionController, Session>(SessionController.new);
