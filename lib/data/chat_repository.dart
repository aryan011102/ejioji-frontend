import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../core/util/ids.dart';
import '../shared/models/chat.dart';
import '../shared/models/game.dart';
import '../shared/models/tile.dart';

/// Conversations.
///
/// A conversation is the accepted request: the match id is the conversation
/// id, and every read and write re-checks that the match is still accepted.
/// There is no separate conversation to fall out of step.
class ChatRepository {
  const ChatRepository(this._api);

  final ApiClient _api;

  Future<List<Conversation>> conversations() async {
    final body = await _api.getJson(Api.conversations);
    return Conversation.listFrom(body.objects('conversations'));
  }

  /// A page of messages.
  ///
  /// [after] catches up from a sequence number, which is what the app does on
  /// every reconnect: numbers are assigned in commit order, so "everything
  /// after 41" can never skip a message that committed late. [before] pages
  /// backwards into history.
  Future<MessagePage> messages(
    String matchId, {
    int? after,
    int? before,
    int limit = 50,
  }) async {
    final body = await _api.getJson(
      Api.messages(matchId),
      query: {
        if (after != null) 'after': after,
        if (before != null) 'before': before,
        'limit': limit,
      },
    );
    return MessagePage.fromJson(body);
  }

  /// Sends one message.
  ///
  /// The client id is invented here rather than by the server, so a retry
  /// after a lost response is the same message rather than a second one. A
  /// caller that retries must pass the id it used the first time.
  Future<Message> send(
    String matchId, {
    String? text,
    String? mediaId,
    String? clientId,
    ProfileTile? tile,
    String? storyTitle,
  }) async {
    final body = await _api.post(
      Api.messages(matchId),
      body: {
        'client_id': clientId ?? Ids.uuid(),
        if (text != null) 'text': text,
        if (mediaId != null) 'media_id': mediaId,
        // Their tile, quoted above the text. Only with text.
        if (tile != null) 'tile': tile.toRef(),
        // "Chat about this" on an in common story: its title as shown. The
        // server finds the story itself, so a phone cannot quote words of its
        // own in an "In common" frame.
        if (storyTitle != null) 'story': {'title': storyTitle},
      },
    );
    return Message.fromJson(body);
  }

  /// How many games this person started here wait on the other person, and
  /// how many may: at the cap the server refuses another (FLAMES aside).
  Future<({int waiting, int cap})> gamesWaiting(String matchId) async {
    final body = await _api.getJson(Api.gamesWaiting(matchId));
    return (waiting: body.intOr('waiting', 0), cap: body.intOr('cap', 5));
  }

  /// Cards for a new game, ones the two have not had while there are enough.
  /// Nothing is written until [startGame].
  Future<List<GameCard>> dealGame(String matchId, GameKind game) async {
    final body = await _api.getJson(
      Api.gameDeal(matchId),
      query: {'game': game.wire},
    );
    return body.objects('cards').map(GameCard.fromJson).toList(growable: false);
  }

  /// Emoji clues for a film of this person's own in guess the movie, easiest
  /// first, from the [title] they typed. Only the title is sent; nothing is
  /// written. Empty when the film is not one the model knows: they write
  /// their own.
  Future<List<String>> suggestMovieClues(String matchId, String title) async {
    final body = await _api.post(
      Api.movieClues(matchId),
      body: {'title': title},
    );
    return body.strings('clues');
  }

  /// Starts a game with this person's own answer in it: a pick on each dealt
  /// card, or three statements and which is the lie. FLAMES needs neither.
  /// Each of [cards] is the key of a card dealt, or an [OwnCard] in its place.
  /// Idempotent on [clientId], like a message.
  Future<Message> startGame(
    String matchId, {
    required GameKind game,
    required String clientId,
    List<Object> cards = const [],
    List<int>? picks,
    List<String>? statements,
    int? lie,
    String? text,
    int? cell,
  }) async {
    final body = await _api.post(
      Api.games(matchId),
      body: {
        'client_id': clientId,
        'game': game.wire,
        if (cards.isNotEmpty)
          'cards': [for (final c in cards) c is OwnCard ? c.toJson() : c],
        if (picks != null) 'picks': picks,
        if (statements != null) 'statements': statements,
        if (lie != null) 'lie': lie,
        if (text != null) 'text': text,
        if (cell != null) 'cell': cell,
      },
    );
    return Message.fromJson(body);
  }

  /// The other person's turn, which finishes the game.
  Future<Message> answerGame(
    String matchId,
    String gameId, {
    required String clientId,
    List<int>? picks,
    int? guess,
    String? text,
  }) async {
    final body = await _api.post(
      Api.gameAnswer(matchId, gameId),
      body: {
        'client_id': clientId,
        if (picks != null) 'picks': picks,
        if (guess != null) 'guess': guess,
        if (text != null) 'text': text,
      },
    );
    return Message.fromJson(body);
  }

  /// A square on a tic tac toe board, or a guess in Worduel, on this person's
  /// turn.
  Future<Message> moveGame(
    String matchId,
    String gameId, {
    required String clientId,
    int? cell,
    String? word,
  }) async {
    final body = await _api.post(
      Api.gameMove(matchId, gameId),
      body: {
        'client_id': clientId,
        if (cell != null) 'cell': cell,
        if (word != null) 'word': word,
      },
    );
    return Message.fromJson(body);
  }

  /// Marks everything up to [seq] read. Read marks are the only receipt this
  /// product has: there is no delivered, no presence and no last seen.
  Future<int> markRead(String matchId, int seq) async {
    final body = await _api.post(Api.markRead(matchId), body: {'seq': seq});
    return body.intOr('read_seq', seq);
  }
}
