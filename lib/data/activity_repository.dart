import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../shared/models/activity.dart';

/// The Notifications page.
///
/// The server keeps no list of notifications: every row is worked out from
/// requests, matches, messages, moderation and new tiles as they are now. The
/// only thing stored is when the page was last opened.
class ActivityRepository {
  const ActivityRepository(this._api);

  final ApiClient _api;

  Future<ActivityPage> load() async =>
      ActivityPage.fromJson(await _api.getJson(Api.activity));

  /// Everything on the page up to now stops being new.
  Future<void> markSeen() => _api.postEmpty(Api.activitySeen);
}
