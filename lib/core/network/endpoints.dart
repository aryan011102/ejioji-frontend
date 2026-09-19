/// Every path the app knows, in one place.
///
/// These are the real paths, read off the backend's OpenAPI schema rather than
/// guessed: repositories reference these constants instead of string literals,
/// so the day the backend renames something there is one file to change and
/// the compiler finds the callers.
///
/// [Env.apiBaseUrl] is the origin only (`https://api.example.com`). The
/// version prefix lives here, because it is part of the contract rather than
/// part of the deployment.
abstract final class Api {
  static const prefix = '/api/v1';

  // Auth. `logout` signs out every device and takes no body.
  static const otpStart = '$prefix/auth/otp/start';
  static const otpVerify = '$prefix/auth/otp/verify';
  static const refresh = '$prefix/auth/refresh';
  static const logout = '$prefix/auth/logout';
  static const me = '$prefix/auth/me';

  // Consent. Nothing may be connected without an open grant for its purpose,
  // so this is not an optional screen.
  static const consentNotices = '$prefix/consent/notices';
  static const consentGrants = '$prefix/consent/grants';
  static const consentRevoke = '$prefix/consent/revoke';

  // Connections and the ingestion run the client polls.
  static const connections = '$prefix/connections';
  static String authorize(String source) => '$prefix/connections/$source/authorize';
  static String complete(String source) => '$prefix/connections/$source/complete';
  static const netflixUpload = '$prefix/connections/netflix/upload';
  static const spotifyUpload = '$prefix/connections/spotify/upload';
  static String run(String runId) => '$prefix/ingestion/runs/$runId';

  // Insights. The tiles are candidates until they are picked onto the profile.
  static const insightCandidates = '$prefix/insights/candidates';
  static const insightsMore = '$prefix/insights/more';

  // Profile.
  static const profile = '$prefix/profile';
  static const profileOptions = '$prefix/profile/options';
  static const profilePhotos = '$prefix/profile/photos';
  static const profilePrompts = '$prefix/profile/prompts';
  static String promptAnswer(String key) => '$prefix/profile/prompts/$key';
  static const profileTiles = '$prefix/profile/tiles';
  static const tileMediaAll = '$prefix/profile/tiles/media';
  static String tileMedia(String kind, String key) =>
      '$prefix/profile/tiles/$kind/${Uri.encodeComponent(key)}/media';
  static const publish = '$prefix/profile/publish';

  // Media. Bytes go straight to blob storage on the URL this hands back; they
  // never travel through the API.
  static const mediaUploads = '$prefix/media/uploads';
  static const media = '$prefix/media';
  static String mediaComplete(String id) => '$prefix/media/$id/complete';
  static String mediaItem(String id) => '$prefix/media/$id';

  // Matching. There is no like: a request is sent, and an accepted request is
  // the match.
  static const preferences = '$prefix/matching/preferences';
  static const feed = '$prefix/matching/feed';
  static const requests = '$prefix/matching/requests';
  static const incoming = '$prefix/matching/requests/incoming';
  static const outgoing = '$prefix/matching/requests/outgoing';
  static String acceptRequest(String id) => '$prefix/matching/requests/$id/accept';
  static String declineRequest(String id) => '$prefix/matching/requests/$id/decline';
  static const matches = '$prefix/matching/matches';
  static String endMatch(String matchId) => '$prefix/matching/matches/$matchId';
  static const passes = '$prefix/matching/passes';
  static const blocks = '$prefix/matching/blocks';
  static String unblock(String userId) => '$prefix/matching/blocks/$userId';

  // Chat. The conversation id is the match id; chat holds no id of its own.
  static const conversations = '$prefix/chat/conversations';
  static String messages(String matchId) => '$prefix/chat/$matchId/messages';
  static String markRead(String matchId) => '$prefix/chat/$matchId/read';
  static String chatUpload(String matchId) => '$prefix/chat/$matchId/uploads';
  static const chatSocket = '$prefix/chat/ws';

  // Notifications.
  static const pushToken = '$prefix/notifications/push-token';
  static const pushTokenClear = '$prefix/notifications/push-token/clear';

  // Safety. Reporting always blocks; blocking works on its own.
  static const reports = '$prefix/trust/reports';

  // Account.
  static const deleteAccount = '$prefix/account/delete';
}
