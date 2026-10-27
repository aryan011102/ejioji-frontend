import 'package:ejioji/data/verification_repository.dart';
import 'package:ejioji/shared/models/enums.dart';
import 'package:ejioji/shared/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shapes copied from the backend's profile/verification_router.py and
/// matching/schemas.py. A mistake here is a tick that never shows, or one
/// that shows for nobody the server verified.
void main() {
  test('the status the server sends is the status the app shows', () {
    final v = Verification.fromJson({
      'status': 'verified',
      'verified': true,
      'verified_at': '2026-09-25T10:00:00+00:00',
      'available': true,
      'selfie': {
        'status': 'outdated',
        'verified': false,
        'verified_at': '2026-10-27T10:00:00+00:00',
        'available': true,
      },
      'tier': 'blue',
    });
    expect(v.verified, isTrue);
    expect(v.tier, VerificationTier.blue);
    expect(v.digilocker.verified, isTrue);
    expect(v.digilocker.available, isTrue);
    expect(v.digilocker.verifiedAt, isNotNull);
    expect(v.selfie.status, VerificationStatus.outdated);
    expect(v.selfie.verified, isFalse);
  });

  test('both checks standing are gold', () {
    final v = Verification.fromJson({
      'status': 'verified',
      'verified': true,
      'verified_at': '2026-09-25T10:00:00+00:00',
      'available': true,
      'selfie': {
        'status': 'verified',
        'verified': true,
        'verified_at': '2026-10-27T10:00:00+00:00',
        'available': true,
      },
      'tier': 'gold',
    });
    expect(v.tier, VerificationTier.gold);
  });

  test('a server from before the selfie reads as DigiLocker alone', () {
    final v = Verification.fromJson({
      'status': 'verified',
      'verified': true,
      'verified_at': '2026-09-25T10:00:00+00:00',
      'available': true,
    });
    expect(v.tier, VerificationTier.blue);
    expect(v.selfie.status, VerificationStatus.none);
    expect(v.selfie.available, isFalse);
  });

  test('an unknown status is never read as verified', () {
    final v = Verification.fromJson({
      'status': 'something_new',
      'verified': true,
      'verified_at': null,
      'available': false,
    });
    expect(v.digilocker.status, VerificationStatus.none);
    expect(v.verified, isFalse);
  });

  test('a selfie refusal names the photos and says whether photos fix it', () {
    final r = SelfieResult.fromJson({
      'outcome': 'photos_differ',
      'verified': false,
      'message': 'Some of your photos do not look like your selfie.',
      'differing_photo_ids': ['m-2'],
      'tier': 'none',
    });
    expect(r.verified, isFalse);
    expect(r.differingPhotoIds, ['m-2']);
    expect(r.aboutPhotos, isTrue);
    final dark = SelfieResult.fromJson({
      'outcome': 'no_face',
      'verified': false,
      'message': 'We could not see a face.',
      'differing_photo_ids': <String>[],
      'tier': 'none',
    });
    expect(dark.aboutPhotos, isFalse);
    final done = SelfieResult.fromJson({
      'outcome': 'verified',
      'verified': true,
      'message': 'You are verified.',
      'differing_photo_ids': <String>[],
      'tier': 'gold',
    });
    expect(done.tier, VerificationTier.gold);
  });

  test('a refusal carries the outcome and the server message', () {
    final r = VerificationResult.fromJson({
      'outcome': 'birth_date_differs',
      'verified': false,
      'message': 'The date of birth on your profile is not the one on your '
          'Aadhaar. Correct it and verify again.',
    });
    expect(r.verified, isFalse);
    expect(r.declined, isFalse);
    expect(r.message, contains('date of birth'));
    final declined = VerificationResult.fromJson({
      'outcome': 'declined',
      'verified': false,
      'message': 'Verification was cancelled.',
    });
    expect(declined.declined, isTrue);
  });

  test('a card carries the tick, and a card without it has none', () {
    Map<String, Object?> card({bool? verified}) => {
          'user_id': 'u-1',
          'first_name': 'Priya',
          'age': 27,
          'city': 'bengaluru',
          'languages': <String>[],
          'education': null,
          'pronouns': null,
          'photos': <Object>[],
          'tiles': <Object>[],
          if (verified != null) 'verified': verified,
        };
    expect(Candidate.fromJson(card(verified: true)).verified, isTrue);
    expect(Candidate.fromJson(card(verified: false)).verified, isFalse);
    expect(Candidate.fromJson(card()).verified, isFalse);
    expect(
      Candidate.fromJson(card(verified: true)).withSocials(const []).verified,
      isTrue,
    );
  });

  test('a card carries the tier, and an older card without one is blue', () {
    Map<String, Object?> card(String? tier) => {
      'user_id': 'u-1',
      'first_name': 'Priya',
      'age': 27,
      'city': 'bengaluru',
      'photos': <Object>[],
      'tiles': <Object>[],
      'verified': tier != 'none',
      if (tier != null) 'verification_tier': tier,
    };
    expect(Candidate.fromJson(card('gold')).tier, VerificationTier.gold);
    expect(Candidate.fromJson(card('none')).verified, isFalse);
    expect(Candidate.fromJson(card(null)).tier, VerificationTier.blue);
    expect(
      Candidate.fromJson(card('gold')).withSocials(const []).tier,
      VerificationTier.gold,
    );
  });

  test('the consent purposes match the backend names', () {
    expect(
      ConsentPurpose.parse('identity_verification'),
      ConsentPurpose.identityVerification,
    );
    expect(
      ConsentPurpose.parse('selfie_verification'),
      ConsentPurpose.selfieVerification,
    );
  });
}
