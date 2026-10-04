import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/session/session.dart';
import '../shared/models/blind.dart';
import '../shared/models/enums.dart';
import '../shared/models/person.dart';
import '../shared/models/tile.dart';
import 'providers.dart';

/// Whether Home is showing its other face, Go blind.
///
/// Not a route: Blind is Home turned over, reached by holding the Home icon,
/// so the tab bar reads this to draw the sparkle and Home reads it to flip.
/// Tapping Home from another tab comes back to whichever face was showing.
final blindModeProvider = StateProvider<bool>((ref) {
  // A new account on this phone starts on the ordinary face.
  ref.watch(sessionProvider.select((s) => s.userId));
  return false;
});

@immutable
class BlindState {
  const BlindState({
    this.tiles = const [],
    this.category,
    this.categories = const [],
    this.deal = 0,
    this.seed,
    this.cursor,
    this.started = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.asked = const {},
  });

  /// Everything dealt so far in this deal, in the server's order.
  final List<BlindTile> tiles;

  /// The tab picked. Null is All.
  final TileCategory? category;

  /// The tabs after All: the categories somebody in the All deal has a tile
  /// in, in the app's usual order. A category with nobody in it right now
  /// gets no tab rather than an empty screen.
  final List<TileCategory> categories;

  /// Bumped on every new deal, so the plane starts over rather than carrying
  /// its place into a different set of tiles.
  final int deal;

  final int? seed;
  final int? cursor;
  final bool started;
  final bool loading;
  final bool loadingMore;
  final ApiException? error;

  /// People asked to chat from here. Their tiles stay where they are for the
  /// rest of this deal, marked, rather than leaving holes; the next deal
  /// leaves them out, as the server does.
  final Set<String> asked;

  bool get hasMore => cursor != null;

  BlindState copyWith({
    List<BlindTile>? tiles,
    TileCategory? category,
    bool clearCategory = false,
    List<TileCategory>? categories,
    int? deal,
    int? seed,
    int? cursor,
    bool clearCursor = false,
    bool? started,
    bool? loading,
    bool? loadingMore,
    ApiException? error,
    bool clearError = false,
    Set<String>? asked,
  }) =>
      BlindState(
        tiles: tiles ?? this.tiles,
        category: clearCategory ? null : (category ?? this.category),
        categories: categories ?? this.categories,
        deal: deal ?? this.deal,
        seed: seed ?? this.seed,
        cursor: clearCursor ? null : (cursor ?? this.cursor),
        started: started ?? this.started,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        asked: asked ?? this.asked,
      );
}

class BlindController extends Notifier<BlindState> {
  @override
  BlindState build() {
    // Rebuilt when the account changes, so nobody inherits the last deal.
    ref.watch(sessionProvider.select((s) => s.userId));
    return const BlindState();
  }

  /// The first time Blind is turned to. Later turns keep the deal and the
  /// place in it.
  void start() {
    if (state.started) return;
    state = state.copyWith(started: true);
    unawaited(_deal());
  }

  /// A fresh deal of the same tab: the shuffle button.
  Future<void> shuffle() => _deal();

  /// A tab. Picking the one already picked does nothing.
  Future<void> choose(TileCategory? category) async {
    if (category == state.category) return;
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
    await _deal();
  }

  Future<void> _deal() async {
    final category = state.category;
    state = state.copyWith(
      tiles: const [],
      loading: true,
      loadingMore: false,
      clearCursor: true,
      clearError: true,
      deal: state.deal + 1,
    );
    final deal = state.deal;
    try {
      final page = await ref
          .read(matchingRepositoryProvider)
          .blind(category: category);
      // A tab tapped, or shuffle pressed, while this was on its way.
      if (state.deal != deal) return;
      state = state.copyWith(
        tiles: page.tiles,
        seed: page.seed,
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        categories: category == null ? _categoriesIn(page.tiles) : null,
        loading: false,
      );
    } on ApiException catch (e) {
      if (state.deal != deal) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// More of this deal, when the plane has used most of what it has. Quietly
  /// does nothing on a failure: the plane wraps around what it already holds.
  Future<void> more() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final deal = state.deal;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await ref.read(matchingRepositoryProvider).blind(
            seed: state.seed,
            after: state.cursor,
            category: state.category,
          );
      if (state.deal != deal) return;
      state = state.copyWith(
        tiles: [...state.tiles, ...page.tiles],
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        categories: state.category == null
            ? _categoriesIn([...state.tiles, ...page.tiles])
            : null,
        loadingMore: false,
      );
    } on ApiException {
      if (state.deal != deal) return;
      // No cursor means nothing more is asked for, so a failing page is not
      // asked for again on every frame.
      state = state.copyWith(loadingMore: false, clearCursor: true);
    }
  }

  /// "Chat about this", from a flicked tile. Throws [ApiException] for the
  /// sheet to show (the daily allowance, a note refused).
  Future<RequestResult> ask(
    Candidate person,
    ProfileTile tile, {
    String? note,
  }) async {
    final result = await ref
        .read(matchingRepositoryProvider)
        .sendRequest(person.userId, tile: tile, note: note);
    state = state.copyWith(asked: {...state.asked, person.userId});
    ref
      ..invalidate(outgoingRequestsProvider)
      // Asking back accepts their request, which opens a conversation.
      ..invalidate(incomingRequestsProvider)
      ..invalidate(conversationsProvider);
    return result;
  }

  static List<TileCategory> _categoriesIn(List<BlindTile> tiles) {
    final present = {for (final t in tiles) t.tile.category};
    return [
      for (final c in TileCategory.values)
        if (c != TileCategory.unknown && present.contains(c)) c,
    ];
  }
}

final blindProvider =
    NotifierProvider<BlindController, BlindState>(BlindController.new);
