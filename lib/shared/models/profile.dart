import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';
import 'enums.dart';
import 'media.dart';
import 'tile.dart';

/// The manual half of a profile. Four fields, deliberately.
///
/// `lastName` exists from 2026-09-20 and is optional. It was deliberately absent
/// before that, because a surname next to purchase history is how caste gets
/// inferred, and this product holds the purchase history. The backend decision
/// log for that date is where the reversal is argued; nothing in matching reads
/// it.
@immutable
class Profile {
  const Profile({
    required this.firstName,
    required this.birthDate,
    required this.age,
    required this.gender,
    required this.city,
    this.lastName,
    this.languages = const [],
    this.education,
  });

  final String firstName;
  final String? lastName;
  final DateTime birthDate;

  /// Computed by the server, so it cannot drift from the birth date.
  final int age;

  final Gender? gender;
  final City city;

  /// Empty means not stated, which is not the same as speaking nothing: it
  /// means this person is never matched on language.
  final List<Language> languages;
  final Education? education;

  /// The name as it is shown. A person with no last name is just their first.
  String get displayName =>
      lastName == null || lastName!.isEmpty ? firstName : '$firstName $lastName';

  static Profile fromJson(Json j) => Profile(
        firstName: j.str('first_name'),
        lastName: j.strOrNull('last_name'),
        birthDate: j.date('birth_date'),
        age: j.intOr('age', 0),
        gender: Gender.parse(j.strOrNull('gender')),
        city: City.parse(j.strOrNull('city')),
        languages: [
          for (final raw in j.strings('languages'))
            if (Language.parse(raw) case final l?) l,
        ],
        education: Education.parse(j.strOrNull('education')),
      );
}

/// One reason a profile cannot be published yet, with the numbers so the
/// screen can show progress instead of a refusal.
@immutable
class PublishBlocker {
  const PublishBlocker({
    required this.code,
    required this.have,
    required this.need,
  });

  final Blocker code;
  final int have;
  final int need;

  String get message => switch (code) {
        Blocker.profileMissing => 'Add your name, age, gender and city',
        Blocker.tooFewTiles => 'Pick $need tiles for your profile, you have $have',
        Blocker.tooFewCategories =>
          'Your tiles need to cover $need categories, they cover $have',
        Blocker.tooFewPhotos => 'Add $need photos, you have $have',
        Blocker.unknown => 'Something is still missing',
      };
}

/// Whether a profile is out there.
///
/// [published] is the person's wish. [visible] is that wish and the gate
/// passing right now, and it is derived on every read: tiles can vanish
/// without the person doing anything (a consent withdrawal), and when they do
/// the profile has to stop showing on its own.
@immutable
class PublishState {
  const PublishState({
    required this.published,
    required this.visible,
    required this.blocking,
    required this.underReview,
  });

  final bool published;
  final bool visible;
  final List<PublishBlocker> blocking;

  /// Held by moderation. The person is told rather than left wondering why
  /// nothing is happening.
  final bool underReview;

  bool get canPublish => blocking.isEmpty;

  static PublishState fromJson(Json j) => PublishState(
        published: j.flag('published'),
        visible: j.flag('visible'),
        underReview: j.flag('under_review'),
        blocking: j
            .objects('blocking')
            .map(
              (b) => PublishBlocker(
                code: Blocker.parse(b.strOrNull('code')),
                have: b.intOr('have', 0),
                need: b.intOr('need', 0),
              ),
            )
            .toList(growable: false),
      );
}

/// Everything the profile screen needs, in one call.
@immutable
class MyProfile {
  const MyProfile({
    required this.photos,
    required this.tiles,
    required this.publish,
    this.profile,
  });

  /// Null until the person has filled the four fields in.
  final Profile? profile;

  final List<MediaAsset> photos;
  final List<ProfileTile> tiles;
  final PublishState publish;

  bool get isComplete => profile != null;

  static MyProfile fromJson(Json j) {
    final p = j.objectOrNull('profile');
    return MyProfile(
      profile: p == null ? null : Profile.fromJson(p),
      photos: MediaAsset.listFrom(j.objects('photos')),
      tiles: ProfileTile.listFrom(j.objects('tiles')),
      publish: PublishState.fromJson(j.object('publish')),
    );
  }
}

/// The closed lists the profile form offers. They come from the server so a
/// new city does not need an app release.
@immutable
class ProfileOptions {
  const ProfileOptions({
    required this.genders,
    required this.cities,
    required this.languages,
    required this.educations,
  });

  final List<PromptOption> genders;
  final List<PromptOption> cities;
  final List<PromptOption> languages;
  final List<PromptOption> educations;

  static ProfileOptions fromJson(Json j) => ProfileOptions(
        genders: PromptOption.listFrom(j.objects('genders')),
        cities: PromptOption.listFrom(j.objects('cities')),
        languages: PromptOption.listFrom(j.objects('languages')),
        educations: PromptOption.listFrom(j.objects('educations')),
      );
}

/// The prompt bank, and which of them this person has answered.
@immutable
class PromptBank {
  const PromptBank({required this.prompts, required this.answers});

  final List<Prompt> prompts;
  final List<PromptAnswer> answers;

  PromptAnswer? answerFor(String promptKey) {
    for (final a in answers) {
      if (a.promptKey == promptKey) return a;
    }
    return null;
  }

  List<Prompt> inCategory(TileCategory category) =>
      prompts.where((p) => p.category == category).toList(growable: false);

  static PromptBank fromJson(Json j) => PromptBank(
        prompts: j.objects('prompts').map(Prompt.fromJson).toList(growable: false),
        answers: PromptAnswer.listFrom(j.objects('answers')),
      );
}
