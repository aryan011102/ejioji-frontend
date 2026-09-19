import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../shared/models/enums.dart';
import '../shared/models/media.dart';
import '../shared/models/profile.dart';
import '../shared/models/tile.dart';

/// The person's own profile: the four manual fields, their photos, the tiles
/// they picked, and whether all of that is enough to be published.
class ProfileRepository {
  const ProfileRepository(this._api);

  final ApiClient _api;

  /// Everything the profile screen needs, in one call.
  Future<MyProfile> load() async =>
      MyProfile.fromJson(await _api.getJson(Api.profile));

  /// The closed lists the form offers. Read from the server so that adding a
  /// city does not need an app release.
  Future<ProfileOptions> options() async =>
      ProfileOptions.fromJson(await _api.getJson(Api.profileOptions));

  /// Saves the four fields. There is no surname, no bio, no occupation and no
  /// employer: asking people to describe themselves first is what produces a
  /// conventional profile, and the derived tiles then have to argue with it.
  Future<Profile> save({
    required String firstName,
    required DateTime birthDate,
    required Gender gender,
    required City city,
  }) async {
    final body = await _api.put(
      Api.profile,
      body: {
        'first_name': firstName,
        'birth_date': _isoDate(birthDate),
        'gender': gender.wire,
        'city': city.wire,
      },
    );
    return Profile.fromJson(body);
  }

  Future<PromptBank> prompts() async =>
      PromptBank.fromJson(await _api.getJson(Api.profilePrompts));

  /// Answers one prompt. A written answer is refused if it carries contact
  /// details, which is the server's call rather than this client's: moving
  /// off-platform before a match is the scam path.
  Future<PromptAnswer> answer(
    String promptKey, {
    String? text,
    String? option,
  }) async {
    final body = await _api.put(
      Api.promptAnswer(promptKey),
      body: {
        if (text != null) 'text': text,
        if (option != null) 'option': option,
      },
    );
    return PromptAnswer.fromJson(body);
  }

  /// Deleting an answer deletes its edit history with it. Taking your own
  /// words back should mean they are gone.
  Future<void> deleteAnswer(String promptKey) =>
      _api.deleteEmpty(Api.promptAnswer(promptKey));

  /// Sets which tiles are on the profile, and in what order.
  ///
  /// The order sent is the order shown. A tile left out is hidden from the
  /// profile but still informs matching, which the screen says out loud.
  Future<List<ProfileTile>> setTiles(List<ProfileTile> tiles) async {
    final body = await _api.putList(
      Api.profileTiles,
      body: {'tiles': [for (final t in tiles) t.toRef()]},
    );
    return ProfileTile.listFrom(body);
  }

  /// The same, from bare `{kind, key}` references: for the picker, which adds
  /// tiles that are not on the profile yet and so have no [ProfileTile].
  Future<List<ProfileTile>> setTileRefs(List<Map<String, Object?>> refs) async {
    final body = await _api.putList(Api.profileTiles, body: {'tiles': refs});
    return ProfileTile.listFrom(body);
  }

  /// Sets the photo order. A profile shows at most six.
  Future<List<MediaAsset>> setPhotos(List<String> mediaIds) async {
    final body = await _api.putList(
      Api.profilePhotos,
      body: {'media_ids': mediaIds},
    );
    return MediaAsset.listFrom(body);
  }

  /// Asks to be published. The server answers with the state either way: on a
  /// refusal the blocking list says what is missing, with counts.
  Future<PublishState> publish() async =>
      PublishState.fromJson(await _api.post(Api.publish));

  Future<void> unpublish() => _api.deleteEmpty(Api.publish);

  /// A plain calendar date, with no timezone attached to it.
  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
