import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../shared/models/person.dart';
import '../shared/models/tile.dart';
import 'providers.dart';

/// The feed, as a deck rather than a list.
///
/// Home shows one person at a time, so this holds the slate and a position in
/// it, fetches the next page before the current one runs out, and takes the
/// two actions that move the deck on.
@immutable
class FeedState {
  const FeedState({
    this.cards = const [],
    this.index = 0,
    this.loading = true,
    this.loadingMore = false,
    this.exhausted = false,
    this.error,
    this.cursor,
  });

  final List<Candidate> cards;
  final int index;
  final bool loading;
  final bool loadingMore;

  /// The server has no more to give. Distinct from an empty first page: one
  /// means "you have seen everyone", the other means "your filters match
  /// nobody", and those need different screens.
  final bool exhausted;

  final ApiException? error;
  final int? cursor;

  Candidate? get current => index < cards.length ? cards[index] : null;

  bool get isEmpty => !loading && cards.isEmpty;

  bool get isFinished => !loading && cards.isNotEmpty && current == null;

  FeedState copyWith({
    List<Candidate>? cards,
    int? index,
    bool? loading,
    bool? loadingMore,
    bool? exhausted,
    ApiException? error,
    bool clearError = false,
    int? cursor,
  }) =>
      FeedState(
        cards: cards ?? this.cards,
        index: index ?? this.index,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        exhausted: exhausted ?? this.exhausted,
        error: clearError ? null : (error ?? this.error),
        cursor: cursor ?? this.cursor,
      );
}

class FeedController extends Notifier<FeedState> {
  /// Fetch the next page once there are this few left. The pages are small and
  /// a person can move through several cards quickly; waiting until the deck
  /// is empty would show a spinner mid-swipe.
  static const _prefetchAt = 3;

  @override
  FeedState build() {
    Future.microtask(refresh);
    return const FeedState();
  }

  Future<void> refresh() async {
    state = const FeedState();
    await _fetch(reset: true);
  }

  Future<void> _fetch({bool reset = false}) async {
    if (!reset && (state.loadingMore || state.exhausted)) return;
    state = reset
        ? state.copyWith(loading: true, clearError: true)
        : state.copyWith(loadingMore: true);

    try {
      final page = await ref
          .read(matchingRepositoryProvider)
          .feed(after: reset ? null : state.cursor);

      state = state.copyWith(
        cards: reset ? page.cards : [...state.cards, ...page.cards],
        cursor: page.nextCursor,
        exhausted: !page.hasMore,
        loading: false,
        loadingMore: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, loadingMore: false, error: e);
    }
  }

  /// Moves to the next card, and tops the deck up if it is running low.
  void _advance() {
    state = state.copyWith(index: state.index + 1);
    if (state.cards.length - state.index <= _prefetchAt) {
      unawaited(_fetch());
    }
  }

  /// Not interested, for thirty days. One-sided, and they are never told.
  ///
  /// The card moves on immediately rather than waiting for the server: a feed
  /// that pauses on every pass is unusable, and the worst case of a failed
  /// pass is that the person comes back in a later slate.
  Future<void> pass(String userId) async {
    _advance();
    try {
      await ref.read(matchingRepositoryProvider).pass(userId);
    } on ApiException {
      // Deliberately swallowed. Telling someone their pass did not save is
      // noise they cannot act on.
    }
  }

  /// Asks to chat. Unlike a pass this reports failure, because the daily
  /// allowance runs out and that is something the person needs to know.
  ///
  /// Returns the result when the request went through, and null when it did
  /// not; the caller shows the message.
  Future<RequestResult?> request(String userId, {ProfileTile? tile}) async {
    final result = await ref
        .read(matchingRepositoryProvider)
        .sendRequest(userId, tile: tile);
    _advance();
    ref
      ..invalidate(outgoingRequestsProvider)
      // Asking back accepts their request, which opens a conversation.
      ..invalidate(incomingRequestsProvider)
      ..invalidate(conversationsProvider);
    return result;
  }

  /// After a block or a report, which both remove someone from the feed.
  void dropCurrent() {
    final cards = [...state.cards]..removeAt(state.index);
    state = state.copyWith(cards: cards);
  }
}

final feedProvider =
    NotifierProvider<FeedController, FeedState>(FeedController.new);
