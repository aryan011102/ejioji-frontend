import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../core/util/ids.dart';
import '../shared/models/chat.dart';

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
  }) async {
    final body = await _api.post(
      Api.messages(matchId),
      body: {
        'client_id': clientId ?? Ids.uuid(),
        if (text != null) 'text': text,
        if (mediaId != null) 'media_id': mediaId,
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
