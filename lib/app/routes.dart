/// Every route in the app, named once.
///
/// Paths are literal strings in one file rather than scattered through
/// `context.push('/some/path')` calls, so a rename is a compile error instead
/// of a dead link found in QA.
abstract final class Routes {
  // Sign up
  static const splash = '/';
  static const phone = '/sign-in';
  static const otp = '/sign-in/code';

  // Building a profile
  static const createProfile = '/onboarding/about-you';
  static const consent = '/onboarding/permissions';
  static const connect = '/onboarding/connect';
  static const netflixUpload = '/onboarding/connect/netflix';
  static const spotifyUpload = '/onboarding/connect/spotify';

  /// Carries `?run=<id>`: the run it is watching. There is no such thing as
  /// this screen without one.
  static const reading = '/onboarding/reading';
  static String readingRun(String runId) => '/onboarding/reading?run=$runId';
  static const ready = '/onboarding/ready';
  static const pickCategory = '/onboarding/insights/:index';
  static String pickCategoryAt(int i) => '/onboarding/insights/$i';
  static const profileReview = '/onboarding/review';
  static const profileCreated = '/onboarding/done';

  // The three tabs
  static const home = '/home';
  static const chats = '/chats';
  static const account = '/you';

  // Home's own chrome
  static const filters = '/home/filters';
  static const notifications = '/home/notifications';
  static const feedEmptyFiltered = '/home/nobody';
  static const feedEmptySeen = '/home/all-seen';

  // Chats
  static const conversation = '/chats/:id';
  static String conversationWith(String id) => '/chats/$id';
  static const sharedFriends = '/shared/friends';
  static const sharedFamily = '/shared/family';

  // Safety
  static const reportReason = '/report/:id';
  /// [name] and [matchId] travel with the report: the name for the copy,
  /// the match so the report can cite the conversation it is about.
  static String reportFor(String id, {String? name, String? matchId}) =>
      Uri(
        path: '/report/$id',
        queryParameters: {
          if (name != null) 'name': name,
          if (matchId != null) 'match': matchId,
        },
      ).toString();
  static const reportDetails = '/report/:id/details';
  static String reportDetailsFor(String id) => '/report/$id/details';
  static const reportSent = '/report/:id/sent';
  static String reportSentFor(String id) => '/report/$id/sent';

  // Verification
  static const verify = '/verify';
  static const verifyWhy = '/verify/why';
  static const digilocker = '/verify/digilocker';
  static const digilockerHandoff = '/verify/digilocker/opening';
  static const digilockerDone = '/verify/digilocker/done';
  static const selfie = '/verify/selfie';
  static const selfieStep = '/verify/selfie/:step';
  static String selfieStepAt(int s) => '/verify/selfie/$s';
  static const selfieDone = '/verify/selfie/review';
  static const verifyFailed = '/verify/failed';

  // You
  static const editProfile = '/you/profile';
  static const editInfo = '/you/profile/info';
  static const editSources = '/you/profile/insights';
  static const editCategory = '/you/profile/insights/:index';
  static String editCategoryAt(int i) => '/you/profile/insights/$i';

  static const settings = '/you/settings';
  static const profileViews = '/you/settings/views';
  static const blocked = '/you/settings/blocked';
  static const subscription = '/you/settings/subscription';
  static const support = '/you/settings/support';
  static const takeBreak = '/you/settings/break';
  static const accountDeleted = '/you/settings/deleted';
  static const premium = '/premium';
}
