import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../shared/models/enums.dart';
import '../shared/models/person.dart';

/// The feed, and everything a person can do about someone in it.
///
/// There is no like. Tapping through sends a chat request, which waits in the
/// other person's Requested section until they answer; an accepted request is
/// the match, and it is what opens a conversation.
class MatchingRepository {
  const MatchingRepository(this._api);

  final ApiClient _api;

  Future<MatchPreferences> preferences() async =>
      MatchPreferences.fromJson(await _api.getJson(Api.preferences));

  /// Gender preference is a mutual "show me": two people are candidates only
  /// if each is in the other's set. Someone who has not chosen is shown to
  /// nobody, so this is effectively a gate on appearing at all.
  ///
  /// Passing null for an age bound keeps the server's default, which tracks
  /// the person's own age rather than freezing a number at the birthday.
  Future<MatchPreferences> savePreferences({
    required List<Gender> showGenders,
    int? ageMin,
    int? ageMax,
    List<City> cities = const [],
    List<Language> languages = const [],
    List<Education> educationLevels = const [],
  }) async {
    final body = await _api.put(
      Api.preferences,
      body: {
        'show_genders': [for (final g in showGenders) g.wire],
        'age_min': ageMin,
        'age_max': ageMax,
        'cities': [for (final c in cities) c.wire],
        'languages': [for (final l in languages) l.wire],
        'education_levels': [for (final e in educationLevels) e.wire],
      },
    );
    return MatchPreferences.fromJson(body);
  }

  /// A page of the feed. Browsing is unlimited; it is the requests that are
  /// rationed.
  Future<FeedPage> feed({int? after, int limit = 10}) async {
    final body = await _api.getJson(
      Api.feed,
      query: {if (after != null) 'after': after, 'limit': limit},
    );
    return FeedPage.fromJson(body);
  }

  /// Asks to chat. Comes back accepted when the other person had already
  /// asked you: asking back accepts theirs rather than opening a second row.
  ///
  /// Capped per day. The server counts from the table rather than a cache, so
  /// the number is exact.
  Future<RequestResult> sendRequest(String userId) async {
    final body = await _api.post(Api.requests, body: {'user_id': userId});
    return RequestResult.fromJson(body);
  }

  Future<List<PendingRequest>> incoming() async {
    final body = await _api.getJson(Api.incoming);
    return PendingRequest.listFrom(body.objects('requests'));
  }

  /// Also carries what is left of today's allowance and when it comes back.
  Future<OutgoingRequests> outgoing() async =>
      OutgoingRequests.fromJson(await _api.getJson(Api.outgoing));

  Future<Match> accept(String requestId) async =>
      Match.fromJson(await _api.post(Api.acceptRequest(requestId)));

  /// Declining is final and quiet. The other person is not told; the request
  /// simply leaves their sent list.
  Future<void> decline(String requestId) =>
      _api.postEmpty(Api.declineRequest(requestId));

  Future<List<Match>> matches() async {
    final body = await _api.getJson(Api.matches);
    return Match.listFrom(body.objects('matches'));
  }

  /// Unmatching is final for both, and closes the conversation. It is kept
  /// for fourteen days before deletion, so a report filed late still has its
  /// evidence.
  Future<void> unmatch(String matchId) =>
      _api.deleteEmpty(Api.endMatch(matchId));

  /// Hides someone for thirty days, one-sided. Not permanent, because with
  /// one launch city permanent passes would empty the feed.
  Future<void> pass(String userId) =>
      _api.postEmpty(Api.passes, body: {'user_id': userId});

  Future<List<BlockedPerson>> blocks() async {
    final body = await _api.getJson(Api.blocks);
    return BlockedPerson.listFrom(body.objects('blocked'));
  }

  /// Two-way and immediate: it ends a match as an unmatch does, and declines a
  /// pending request in either direction.
  Future<void> block(String userId) =>
      _api.postEmpty(Api.blocks, body: {'user_id': userId});

  /// Lifting a block only lets the two back into each other's feeds. What the
  /// block ended stays ended.
  Future<void> unblock(String userId) => _api.deleteEmpty(Api.unblock(userId));

  /// Says someone's profile has been on screen long enough to count as a look.
  /// The server decides whether it does (never while you are in stealth or not
  /// showing) and answers the same either way.
  Future<void> recordView(String userId) =>
      _api.postEmpty(Api.views, body: {'user_id': userId});

  Future<ProfileViews> views() async =>
      ProfileViews.fromJson(await _api.getJson(Api.views));
}
