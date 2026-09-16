/// The backend's enums, mirrored.
///
/// Every one of these parses with a fallback rather than throwing. A server
/// that adds a city, a report reason or a media kind must not crash a client
/// that has not shipped yet: an unrecognised value becomes `unknown` and the
/// screen renders around it.
///
/// `wire` is the exact string the API uses. Nothing sends `name` directly,
/// because Dart's `name` and the wire format disagree the moment a value has
/// an underscore in it.
library;

enum Gender {
  woman('woman', 'Woman'),
  man('man', 'Man'),
  nonBinary('non_binary', 'Non-binary');

  const Gender(this.wire, this.label);

  final String wire;
  final String label;

  static Gender? parse(String? raw) {
    for (final v in values) {
      if (v.wire == raw) return v;
    }
    return null;
  }
}

enum City {
  bengaluru('bengaluru', 'Bengaluru'),
  mumbai('mumbai', 'Mumbai'),
  delhiNcr('delhi_ncr', 'Delhi NCR'),
  hyderabad('hyderabad', 'Hyderabad'),
  pune('pune', 'Pune'),
  chennai('chennai', 'Chennai'),
  kolkata('kolkata', 'Kolkata'),
  ahmedabad('ahmedabad', 'Ahmedabad'),
  unknown('', '');

  const City(this.wire, this.label);

  final String wire;
  final String label;

  static City parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => City.unknown);
}

/// The six things a person can consent to: one per source, plus the two that
/// cut across them.
enum ConsentPurpose {
  spotifyImport('spotify_import', 'Spotify'),
  youtubeImport('youtube_import', 'YouTube'),
  gmailReceipts('gmail_receipts', 'Food orders from Gmail'),
  netflixUpload('netflix_upload', 'Netflix history'),
  aiProcessing('ai_processing', 'AI suggestions'),
  matching('matching', 'Matching'),
  unknown('', '');

  const ConsentPurpose(this.wire, this.label);

  final String wire;
  final String label;

  static ConsentPurpose parse(String? raw) => values.firstWhere(
        (v) => v.wire == raw,
        orElse: () => ConsentPurpose.unknown,
      );
}

enum Provider {
  youtube('youtube', 'YouTube'),
  spotify('spotify', 'Spotify'),
  gmail('gmail', 'Food orders'),
  netflix('netflix', 'Netflix'),
  unknown('', '');

  const Provider(this.wire, this.label);

  final String wire;
  final String label;

  /// The purpose that must be granted before this source may be connected.
  ConsentPurpose get purpose => switch (this) {
        Provider.youtube => ConsentPurpose.youtubeImport,
        Provider.spotify => ConsentPurpose.spotifyImport,
        Provider.gmail => ConsentPurpose.gmailReceipts,
        Provider.netflix => ConsentPurpose.netflixUpload,
        Provider.unknown => ConsentPurpose.unknown,
      };

  static Provider parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => Provider.unknown);
}

enum ProviderStatus {
  active('active'),
  disconnected('disconnected'),
  unknown('');

  const ProviderStatus(this.wire);

  final String wire;

  static ProviderStatus parse(String? raw) => values.firstWhere(
        (v) => v.wire == raw,
        orElse: () => ProviderStatus.unknown,
      );
}

/// Where a tile came from. A template tile is one of the deterministic floor
/// tiles and is shown even without AI consent; a model tile was proposed.
enum TileOrigin {
  template('template'),
  model('model'),
  unknown('');

  const TileOrigin(this.wire);

  final String wire;

  static TileOrigin parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => TileOrigin.unknown);
}

/// The categories a tile can belong to.
///
/// The backend has two enums here: insight categories, and the wider prompt
/// set that adds the two only a written answer can fill. One enum covers both,
/// because a profile tile is either kind and the UI groups them together.
enum TileCategory {
  foodDelivery('food_delivery', 'Food delivery', '🍜'),
  goingOut('going_out', 'Going out', '🎟️'),
  shopping('shopping', 'Shopping', '🛍️'),
  travel('travel', 'Travel', '✈️'),
  music('music', 'Music', '🎧'),
  social('social', 'Social', '💬'),
  fitness('fitness', 'Moving', '🏃'),
  watching('watching', 'Watching', '📺'),
  netflix('netflix', 'Netflix', '🎬'),
  chatgpt('chatgpt', 'ChatGPT', '🤖'),
  home('home', 'Living together', '🏠'),
  unknown('', 'Other', '✨');

  const TileCategory(this.wire, this.label, this.glyph);

  final String wire;
  final String label;
  final String glyph;

  /// Only these can carry a derived insight. The rest are answer-only.
  bool get isInsightCategory =>
      this != TileCategory.chatgpt &&
      this != TileCategory.home &&
      this != TileCategory.unknown;

  static TileCategory parse(String? raw) => values.firstWhere(
        (v) => v.wire == raw,
        orElse: () => TileCategory.unknown,
      );
}

enum TileKind {
  insight('insight'),
  prompt('prompt');

  const TileKind(this.wire);

  final String wire;

  static TileKind parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => TileKind.insight);
}

/// How a tile's number should be read. The server also sends a formatted
/// `display_value`, which is what actually gets rendered; this is here so the
/// UI can pick a shape for it.
enum ValueKind {
  count('count'),
  percent('percent'),
  duration('duration'),
  year('year'),
  entity('entity'),
  unknown('');

  const ValueKind(this.wire);

  final String wire;

  static ValueKind parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => ValueKind.unknown);
}

enum AnswerKind {
  text('text'),
  choice('choice'),
  pair('pair');

  const AnswerKind(this.wire);

  final String wire;

  static AnswerKind parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => AnswerKind.text);
}

enum MediaKind {
  photo('photo'),
  livePhoto('live_photo'),
  video('video');

  const MediaKind(this.wire);

  final String wire;

  static MediaKind parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => MediaKind.photo);
}

enum MessageKind {
  text('text'),
  photo('photo'),
  video('video');

  const MessageKind(this.wire);

  final String wire;

  static MessageKind parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => MessageKind.text);
}

/// What is stopping a profile from being published. The server returns the
/// list with counts, so the screen can say "4 of 6" rather than "not ready".
enum Blocker {
  profileMissing('profile_missing'),
  tooFewTiles('too_few_tiles'),
  tooFewCategories('too_few_categories'),
  tooFewPhotos('too_few_photos'),
  unknown('');

  const Blocker(this.wire);

  final String wire;

  static Blocker parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => Blocker.unknown);
}

enum RunStatus {
  pending('pending'),
  fetching('fetching'),
  done('done'),
  empty('empty'),
  failed('failed'),
  unknown('');

  const RunStatus(this.wire);

  final String wire;

  bool get isTerminal =>
      this == RunStatus.done ||
      this == RunStatus.empty ||
      this == RunStatus.failed;

  static RunStatus parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => RunStatus.unknown);
}

enum StepStatus {
  pending('pending'),
  fetching('fetching'),
  done('done'),
  failed('failed'),
  unknown('');

  const StepStatus(this.wire);

  final String wire;

  static StepStatus parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => StepStatus.unknown);
}

/// Why a run ended without data. These are not errors to a person: each one
/// has copy that says what to do next.
enum FailureCode {
  interrupted('interrupted'),
  providerError('provider_error'),
  quotaExhausted('quota_exhausted'),
  accessRevoked('access_revoked'),
  consentWithdrawn('consent_withdrawn'),
  internal('internal'),
  unknown('');

  const FailureCode(this.wire);

  final String wire;

  static FailureCode parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => FailureCode.unknown);
}

/// How much a source actually gave us. The onboarding meter reads this rather
/// than treating a thin connection as a failure.
enum Sufficiency {
  none('none'),
  weak('weak'),
  moderate('moderate'),
  strong('strong'),
  unknown('');

  const Sufficiency(this.wire);

  final String wire;

  static Sufficiency parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => Sufficiency.unknown);
}

enum ReportReason {
  fakeProfile('fake_profile', 'This profile is fake'),
  scam('scam', 'Scam or a request for money'),
  harassment('harassment', 'Harassment or abuse'),
  inappropriate('inappropriate', 'Inappropriate photos or messages'),
  hate('hate', 'Hate speech'),
  underage('underage', 'They appear to be under 18'),
  other('other', 'Something else');

  const ReportReason(this.wire, this.label);

  final String wire;
  final String label;
}

enum DevicePlatform {
  ios('ios'),
  android('android'),
  unknown('unknown');

  const DevicePlatform(this.wire);

  final String wire;
}
