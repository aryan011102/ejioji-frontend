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
    });
    expect(v.verified, isTrue);
    expect(v.available, isTrue);
    expect(v.verifiedAt, isNotNull);

    final outdated = Verification.fromJson({
      'status': 'outdated',
      'verified': false,
      'verified_at': '2026-09-25T10:00:00+00:00',
      'available': true,
    });
    expect(outdated.status, VerificationStatus.outdated);
    expect(outdated.verified, isFalse);
  });

  test('an unknown status is never read as verified', () {
    final v = Verification.fromJson({
      'status': 'something_new',
      'verified': true,
      'verified_at': null,
      'available': false,
    });
    expect(v.status, VerificationStatus.none);
    expect(v.verified, isFalse);
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

  test('the consent purpose matches the backend name', () {
    expect(
      ConsentPurpose.parse('identity_verification'),
      ConsentPurpose.identityVerification,
    );
  });
}
