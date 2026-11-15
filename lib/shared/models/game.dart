import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';

/// The games two matched people can play in a chat. The server decides what
/// each game deals and who may see what; the phone only draws it.
enum GameKind {
  wouldYouRather(
    'would_you_rather',
    'Would you rather',
    'Two choices. Pick yours, then see theirs.',
  ),
  rapidFire('rapid_fire', 'Rapid fire', 'Five quick picks, side by side.'),
  neverHaveIEver(
    'never_have_i_ever',
    'Never have I ever',
    'Have you or haven’t you? Find out together.',
  ),
  twoTruths(
    'two_truths',
    'Two truths and a lie',
    'Write three things about you. They spot the lie.',
  ),
  flames('flames', 'FLAMES', 'The schoolyard classic, with your two names.');

  const GameKind(this.wire, this.title, this.pitch);

  final String wire;
  final String title;

  /// One line under its name in the list.
  final String pitch;

  /// Null for a game this build does not know: it is drawn as its text line.
  static GameKind? parse(String? raw) {
    for (final v in values) {
      if (v.wire == raw) return v;
    }
    return null;
  }
}

/// One card: a question and its two answers.
@immutable
class GameCard {
  const GameCard(
      {required this.key, required this.text, required this.options});

  final String key;
  final String text;
  final List<String> options;

  static GameCard fromJson(Json j) => GameCard(
        key: j.str('key'),
        text: j.str('text'),
        options: j.strings('options'),
      );
}

/// FLAMES, worked out by the server from the two names.
@immutable
class FlamesResult {
  const FlamesResult({
    required this.names,
    required this.letter,
    required this.word,
    required this.line,
  });

  final List<String> names;
  final String letter;
  final String word;
  final String line;

  static FlamesResult? maybe(Json? j) {
    if (j == null) return null;
    return FlamesResult(
      names: j.strings('names'),
      letter: j.str('letter'),
      word: j.str('word'),
      line: j.str('line'),
    );
  }
}

/// A game as it stands, as this person may see it. The other person's answers
/// are null until the server says they may be seen.
@immutable
class GameState {
  const GameState({
    required this.id,
    required this.kind,
    required this.title,
    required this.done,
    required this.startedBy,
    this.cards = const [],
    this.starterPicks,
    this.replyPicks,
    this.statements,
    this.lie,
    this.guess,
    this.flames,
  });

  final String id;

  /// Null for a game this build does not know.
  final GameKind? kind;
  final String title;

  /// Answered, or (FLAMES) worked out the moment it started.
  final bool done;
  final String startedBy;
  final List<GameCard> cards;
  final List<int>? starterPicks;
  final List<int>? replyPicks;
  final List<String>? statements;
  final int? lie;
  final int? guess;
  final FlamesResult? flames;

  bool startedByMe(String me) => startedBy == me;

  /// The newer of two copies of one game. A game only goes from waiting to
  /// done, so a done copy is never replaced by a waiting one that arrived late.
  GameState newer(GameState other) => done && !other.done ? this : other;

  static GameState fromJson(Json j) {
    final statements = j['statements'];
    return GameState(
      id: j.str('id'),
      kind: GameKind.parse(j.strOrNull('game')),
      title: j.strOrNull('title') ?? 'Game',
      done: j.strOrNull('status') == 'done',
      startedBy: j.str('started_by'),
      cards: j.objects('cards').map(GameCard.fromJson).toList(growable: false),
      starterPicks: j['starter_picks'] == null ? null : j.ints('starter_picks'),
      replyPicks: j['reply_picks'] == null ? null : j.ints('reply_picks'),
      statements: statements == null ? null : j.strings('statements'),
      lie: j.intOrNull('lie'),
      guess: j.intOrNull('guess'),
      flames: FlamesResult.maybe(j.objectOrNull('flames')),
    );
  }
}
