import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';

/// The games two matched people can play in a chat. The server decides what
/// each game deals and who may see what; the phone only draws it.
///
/// In the order the games list shows them.
enum GameKind {
  wouldYouRather('would_you_rather', 'Would you rather'),
  rapidFire('rapid_fire', 'Rapid fire'),
  neverHaveIEver('never_have_i_ever', 'Never have I ever'),
  truth('truth', 'Truth'),
  twoTruths('two_truths', 'Two truths and a lie'),
  guessMovie('guess_movie', 'Guess the movie'),
  worduel('worduel', 'Worduel'),
  ticTacToe('tic_tac_toe', 'Tic tac toe'),
  flames('flames', 'FLAMES');

  const GameKind(this.wire, this.title);

  final String wire;
  final String title;

  /// Played a move at a time on one live card, drawn where its newest move is.
  bool get live => this == ticTacToe || this == worduel;

  /// In the games list, to start. Truth is not (Aryan, 2026-11-21: it is a
  /// question, which can be asked in the chat); its games already played
  /// still draw and can still be answered.
  bool get offered => this != truth;

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
  const GameCard({
    required this.key,
    required this.text,
    required this.options,
    this.own = false,
  });

  final String key;
  final String text;
  final List<String> options;

  /// Written by the person who started the game, not dealt.
  final bool own;

  static GameCard fromJson(Json j) => GameCard(
        key: j.str('key'),
        text: j.str('text'),
        options: j.strings('options'),
        own: j['own'] == true,
      );
}

/// A card someone writes in place of one dealt. The server checks it as it
/// checks a message, and makes it a card like any other.
///
/// [text] is the question, the line after "Never have I ever", the emoji
/// clue, or Worduel's word; [options] the two answers, the two sides of a
/// rapid fire card, or the film's title.
@immutable
class OwnCard {
  const OwnCard({this.text, this.options = const []});

  final String? text;
  final List<String> options;

  Map<String, Object?> toJson() => {
        if (text != null) 'text': text,
        if (options.isNotEmpty) 'options': options,
      };

  /// The card as the server will make it, to show before it is sent.
  GameCard preview(GameKind game) => switch (game) {
        GameKind.neverHaveIEver => GameCard(
            key: 'own',
            text: 'Never have I ever ${text ?? ''}.',
            options: const ['I have', 'I haven’t'],
            own: true,
          ),
        GameKind.rapidFire => GameCard(
            key: 'own',
            text: '${options.first} or ${options.last}?',
            options: options,
            own: true,
          ),
        _ =>
          GameCard(key: 'own', text: text ?? '', options: options, own: true),
      };
}

/// One guess in Worduel: the word, and a mark per letter.
@immutable
class WorduelGuess {
  const WorduelGuess({required this.word, required this.marks});

  final String word;

  /// One per letter: 'c' in the right place, 'p' in the word elsewhere, 'a'
  /// not in it.
  final String marks;

  static WorduelGuess fromJson(Json j) =>
      WorduelGuess(word: j.str('word'), marks: j.str('marks'));
}

/// Worduel's rules, as the server has them.
abstract final class Worduel {
  static const letters = 5;
  static const tries = 6;
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
    this.starterText,
    this.replyText,
    this.answer,
    this.board,
    this.turn,
    this.winner,
    this.line,
    this.film,
    this.word,
    this.guesses = const [],
    this.correct,
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

  /// Truth: what each wrote. The starter's is null for the other person until
  /// they have answered.
  final String? starterText;
  final String? replyText;

  /// Guess the movie: which of the card's four options is the film. Null for
  /// the guesser until they have guessed.
  final int? answer;

  /// Tic tac toe: nine of ' ', 'x', 'o', row by row; the starter is x.
  final String? board;

  /// Whose turn it is while the board is being played.
  final String? turn;

  /// Once over: 'x', 'o', or null for a draw; and the line that won.
  final String? winner;
  final List<int>? line;

  /// Guess the movie with the starter's own film (its card has no options):
  /// the title, null for the guesser until they have typed theirs into
  /// [replyText].
  final String? film;

  /// Worduel: the word, null for the guesser until it is over; and each guess
  /// so far, oldest first. [turn] is the guesser while it goes on.
  final String? word;
  final List<WorduelGuess> guesses;

  /// Their own film and Worduel, once over: whether they got it.
  final bool? correct;

  bool startedByMe(String me) => startedBy == me;

  /// Waiting on [me]: their move on a board or in a Worduel, or their answer
  /// to a game the other person started. Never FLAMES, which is not played.
  bool myTurn(String me) {
    final k = kind;
    if (done || k == null || k == GameKind.flames) return false;
    return k.live ? turn == me : startedBy != me;
  }

  /// Guess the movie with the starter's own film, which is typed, not picked.
  bool get ownFilm =>
      kind == GameKind.guessMovie &&
      cards.isNotEmpty &&
      cards.first.own &&
      cards.first.options.isEmpty;

  /// Moves so far on a board or in a Worduel: a game only ever gains them.
  int get marks =>
      (board == null ? 0 : board!.replaceAll(' ', '').length) + guesses.length;

  /// The newer of two copies of one game. A game only goes forward, from
  /// waiting to done and, on a board or in a Worduel, from fewer moves to more,
  /// so a copy that arrived late never undoes a move.
  GameState newer(GameState other) {
    if (done != other.done) return done ? this : other;
    return marks > other.marks ? this : other;
  }

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
      starterText: j.strOrNull('starter_text'),
      replyText: j.strOrNull('reply_text'),
      answer: j.intOrNull('answer'),
      board: j.strOrNull('board'),
      turn: j.strOrNull('turn'),
      winner: j.strOrNull('winner'),
      line: j['line'] == null ? null : j.ints('line'),
      film: j.strOrNull('film'),
      word: j.strOrNull('word'),
      guesses: j['guesses'] == null
          ? const []
          : j
              .objects('guesses')
              .map(WorduelGuess.fromJson)
              .toList(growable: false),
      correct: j['correct'] is bool ? j['correct'] as bool : null,
    );
  }
}
