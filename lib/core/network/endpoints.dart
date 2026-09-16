/// Every path the app knows, in one place.
///
/// Repositories reference these constants rather than string literals, so the
/// day the backend renames something there is one file to change and the
/// compiler finds the callers.
abstract final class Api {
  // Auth
  static const requestOtp = '/auth/otp/request';
  static const verifyOtp = '/auth/otp/verify';
  static const refresh = '/auth/refresh';
  static const signOut = '/auth/sign-out';

  // Me
  static const me = '/me';
  static const meProfile = '/me/profile';
  static const mePhotos = '/me/photos';
  static const meDelete = '/me';
  static const mePause = '/me/pause';
  static const meResume = '/me/resume';
  static const meViews = '/me/profile-views';
  static const meBlocked = '/me/blocked';
  static const meSubscription = '/me/subscription';

  // Linked accounts and insights
  static const sources = '/sources';
  static String sourceRefresh(String id) => '/sources/$id/refresh';
  static String sourceUnlink(String id) => '/sources/$id';
  static const categories = '/insights/categories';
  static String category(String id) => '/insights/categories/$id';
  static const picks = '/insights/picks';

  // Feed
  static const feed = '/feed';
  static const filters = '/feed/filters';
  static String pass(String userId) => '/feed/$userId/pass';
  static const notifications = '/notifications';

  // Verification
  static const verificationStatus = '/verification';
  static const digilockerStart = '/verification/digilocker/start';
  static const digilockerFinish = '/verification/digilocker/callback';
  static const selfieSubmit = '/verification/selfie';
  static const selfiePose = '/verification/selfie/pose';

  // Chats
  static const threads = '/chats';
  static String thread(String id) => '/chats/$id';
  static String messages(String id) => '/chats/$id/messages';
  static String star(String id) => '/chats/$id/star';
  static String shareScopes(String id) => '/chats/$id/share';

  // Safety
  static const report = '/safety/reports';
  static String block(String userId) => '/safety/block/$userId';

  // Billing — the client never sees a price it did not get from here, and
  // never confirms a purchase itself; the store receipt is verified server
  // side.
  static const plans = '/billing/plans';
  static const purchase = '/billing/purchase';
}
