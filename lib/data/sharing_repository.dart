import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';

/// Who a link is for. Friends see the profile as it stands; family see a few
/// plain sentences about the person and their answers in their own words.
enum ShareAudience {
  friends('friends'),
  family('family');

  const ShareAudience(this.wire);
  final String wire;

  static ShareAudience parse(String value) =>
      values.firstWhere((a) => a.wire == value, orElse: () => friends);
}

/// A link that still works. Its address is not here: the server sends that
/// once, when the link is made, and keeps only a hash of it.
class ShareLink {
  const ShareLink({
    required this.id,
    required this.audience,
    required this.createdAt,
    required this.expiresAt,
  });

  factory ShareLink.fromJson(Json json) => ShareLink(
        id: json.str('id'),
        audience: ShareAudience.parse(json.str('audience')),
        createdAt: json.time('created_at'),
        expiresAt: json.time('expires_at'),
      );

  final String id;
  final ShareAudience audience;
  final DateTime createdAt;
  final DateTime expiresAt;
}

/// Where sharing stands in one match.
class ShareState {
  const ShareState({
    required this.meReady,
    required this.themReady,
    required this.links,
  });

  factory ShareState.fromJson(Json json) => ShareState(
        meReady: json.flag('me_ready'),
        themReady: json.flag('them_ready'),
        links: json.objects('links').map(ShareLink.fromJson).toList(),
      );

  final bool meReady;
  final bool themReady;

  /// Mine, about them, newest first. Always empty until both are ready.
  final List<ShareLink> links;

  bool get canShare => meReady && themReady;
}

/// A link just made. [url] is the only time the address exists anywhere.
class NewShareLink {
  const NewShareLink({required this.link, required this.url});

  final ShareLink link;
  final String url;
}

/// Sharing a match's profile with friends and family.
///
/// Both people say they are ready before either can make a link, so nobody's
/// profile leaves the app on the other person's say alone. Taking the ready
/// back stops every link in the match, made by either of them.
class SharingRepository {
  const SharingRepository(this._api);

  final ApiClient _api;

  Future<ShareState> load(String matchId) async =>
      ShareState.fromJson(await _api.getJson(Api.sharing(matchId)));

  Future<ShareState> ready(String matchId) async =>
      ShareState.fromJson(await _api.put(Api.sharingReady(matchId)));

  Future<ShareState> takeBack(String matchId) async =>
      ShareState.fromJson(await _api.delete(Api.sharingReady(matchId)));

  /// 409 `share_not_ready` until both are ready; 409 `share_limit` when this
  /// person already holds as many working links as the server allows.
  Future<NewShareLink> makeLink(String matchId, ShareAudience audience) async {
    final body = await _api.post(
      Api.sharingLinks(matchId),
      body: {'audience': audience.wire},
    );
    return NewShareLink(link: ShareLink.fromJson(body), url: body.str('url'));
  }

  Future<void> switchOff(String linkId) =>
      _api.deleteEmpty(Api.sharingLink(linkId));
}
