import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';
import 'enums.dart';
import 'media.dart';
import 'social.dart';
import 'tile.dart';

/// Someone as the feed shows them.
///
/// This is everything a stranger is allowed to see, and the server decides
/// what that is: the tiles here are the ones the person picked onto their
/// profile, never their unpicked candidates, and there is no score, no
/// preference and no distance in it.
@immutable
class Candidate {
  const Candidate({
    required this.userId,
    required this.firstName,
    required this.age,
    required this.city,
    this.languages = const [],
    this.education,
    this.pronouns,
    required this.photos,
    required this.tiles,
    this.socials = const [],
  });

  final String userId;
  final String firstName;
  final int age;
  final City city;

  /// The same three the header shows on your own profile, so a card reads the
  /// same way. The surname is deliberately not here: it is shown to its owner
  /// alone, because a surname beside purchase history is the caste inference.
  final List<Language> languages;
  final Education? education;
  final Pronouns? pronouns;
  final List<MediaAsset> photos;
  final List<ProfileTile> tiles;

  /// Their Instagram, X and LinkedIn. Empty for everyone but a match: the
  /// server hands these over only with a match, never on a card or a request.
  final List<SocialLink> socials;

  Candidate withSocials(List<SocialLink> socials) => Candidate(
        userId: userId,
        firstName: firstName,
        age: age,
        city: city,
        languages: languages,
        education: education,
        pronouns: pronouns,
        photos: photos,
        tiles: tiles,
        socials: socials,
      );

  MediaAsset? get leadPhoto => photos.isEmpty ? null : photos.first;

  static Candidate fromJson(Json j) => Candidate(
        userId: j.str('user_id'),
        firstName: j.str('first_name'),
        age: j.intOr('age', 0),
        city: City.parse(j.strOrNull('city')),
        languages: [
          for (final raw in j.strings('languages'))
            if (Language.parse(raw) case final l?) l,
        ],
        education: Education.parse(j.strOrNull('education')),
        pronouns: Pronouns.parse(j.strOrNull('pronouns')),
        photos: MediaAsset.listFrom(j.objects('photos')),
        tiles: ProfileTile.listFrom(j.objects('tiles')),
      );

  static List<Candidate> listFrom(List<Json> items) =>
      items.map(Candidate.fromJson).toList(growable: false);
}

/// A page of the feed. [nextCursor] is null when the slate is exhausted.
@immutable
class FeedPage {
  const FeedPage({required this.cards, this.nextCursor});

  final List<Candidate> cards;
  final int? nextCursor;

  bool get hasMore => nextCursor != null;

  static FeedPage fromJson(Json j) => FeedPage(
        cards: Candidate.listFrom(j.objects('cards')),
        nextCursor: j.intOrNull('next_cursor'),
      );
}

/// The small form of a person, for a chat list row.
@immutable
class Person {
  const Person({required this.userId, this.firstName, this.photo});

  final String userId;
  final String? firstName;
  final MediaAsset? photo;

  String get displayName => firstName ?? 'Someone';

  static Person fromJson(Json j) {
    final photo = j.objectOrNull('photo');
    return Person(
      userId: j.str('user_id'),
      firstName: j.strOrNull('first_name'),
      photo: photo == null ? null : MediaAsset.fromJson(photo),
    );
  }
}

/// A chat request waiting for an answer, in either direction.
@immutable
class PendingRequest {
  const PendingRequest({
    required this.id,
    required this.requestedAt,
    required this.person,
  });

  final String id;
  final DateTime requestedAt;

  /// The full card, because the point of the Requested section is that you
  /// see someone properly before answering.
  final Candidate person;

  static PendingRequest fromJson(Json j) => PendingRequest(
        id: j.str('id'),
        requestedAt: j.time('requested_at'),
        person: Candidate.fromJson(j.object('person')),
      );

  static List<PendingRequest> listFrom(List<Json> items) =>
      items.map(PendingRequest.fromJson).toList(growable: false);
}

/// What is left of today's allowance, and when it comes back.
@immutable
class OutgoingRequests {
  const OutgoingRequests({
    required this.requests,
    required this.leftToday,
    required this.resetsAt,
  });

  final List<PendingRequest> requests;
  final int leftToday;
  final DateTime resetsAt;

  static OutgoingRequests fromJson(Json j) => OutgoingRequests(
        requests: PendingRequest.listFrom(j.objects('requests')),
        leftToday: j.intOr('requests_left_today', 0),
        resetsAt: j.time('resets_at'),
      );
}

/// An accepted request. This is the match, and the id is also the id of the
/// conversation it opened.
@immutable
class Match {
  const Match({
    required this.id,
    required this.matchedAt,
    required this.person,
  });

  final String id;
  final DateTime matchedAt;
  final Candidate person;

  static Match fromJson(Json j) => Match(
        id: j.str('id'),
        matchedAt: j.time('matched_at'),
        person: Candidate.fromJson(j.object('person'))
            .withSocials(SocialLink.listFrom(j.objects('socials'))),
      );

  static List<Match> listFrom(List<Json> items) =>
      items.map(Match.fromJson).toList(growable: false);
}

/// The answer to sending a request. It comes back `accepted` when the other
/// person had already asked you: asking back accepts theirs.
@immutable
class RequestResult {
  const RequestResult({required this.id, required this.accepted});

  final String id;
  final bool accepted;

  static RequestResult fromJson(Json j) => RequestResult(
        id: j.str('id'),
        accepted: j.strOrNull('status') == 'accepted',
      );
}

@immutable
class BlockedPerson {
  const BlockedPerson({
    required this.userId,
    required this.blockedAt,
    this.firstName,
    this.photo,
  });

  final String userId;
  final DateTime blockedAt;
  final String? firstName;
  final MediaAsset? photo;

  String get displayName => firstName ?? 'Someone';

  static BlockedPerson fromJson(Json j) {
    final photo = j.objectOrNull('photo');
    return BlockedPerson(
      userId: j.str('user_id'),
      blockedAt: j.time('blocked_at'),
      firstName: j.strOrNull('first_name'),
      photo: photo == null ? null : MediaAsset.fromJson(photo),
    );
  }

  static List<BlockedPerson> listFrom(List<Json> items) =>
      items.map(BlockedPerson.fromJson).toList(growable: false);
}

/// Who a person wants to be shown. The gender set holds both ways: two people
/// are candidates only if each is in the other's set.
@immutable
class MatchPreferences {
  const MatchPreferences({
    required this.showGenders,
    required this.ageIsDefault,
    this.ageMin,
    this.ageMax,
    this.cities = const [],
    this.languages = const [],
    this.educationLevels = const [],
  });

  final List<Gender> showGenders;

  /// The three filters added 2026-09-20. Empty narrows nothing, and empty
  /// cities means your own city, which is what the feed always did.
  final List<City> cities;
  final List<Language> languages;
  final List<Education> educationLevels;

  /// Null means the server's default, which tracks the person's own age as
  /// their birthday moves rather than freezing a number.
  final int? ageMin;
  final int? ageMax;
  final bool ageIsDefault;

  /// Someone who has not chosen is shown to nobody, so this is the gate on
  /// appearing in the feed at all.
  bool get isSet => showGenders.isNotEmpty;

  static MatchPreferences fromJson(Json j) {
    final raw = j['show_genders'];
    return MatchPreferences(
      showGenders: raw is List
          ? raw
              .whereType<String>()
              .map(Gender.parse)
              .whereType<Gender>()
              .toList(growable: false)
          : const [],
      ageMin: j.intOrNull('age_min'),
      ageMax: j.intOrNull('age_max'),
      ageIsDefault: j.flag('age_is_default', fallback: true),
      cities: [
        for (final raw in j.strings('cities'))
          if (City.parse(raw) case final c when c != City.unknown) c,
      ],
      languages: [
        for (final raw in j.strings('languages'))
          if (Language.parse(raw) case final l?) l,
      ],
      educationLevels: [
        for (final raw in j.strings('education_levels'))
          if (Education.parse(raw) case final e?) e,
      ],
    );
  }
}
