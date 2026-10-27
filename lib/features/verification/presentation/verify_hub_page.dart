import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../data/verification_repository.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

/// Verification: where it stands, and the two ways to it.
///
/// DigiLocker checks the profile's name and date of birth against Aadhaar; the
/// selfie checks that the profile's photos are of the person holding the
/// phone. Either earns the blue tick, both earn gold.
///
/// DigiLocker holds Indian identities only, so for a profile in a city abroad
/// it is shown greyed out and the selfie is the way (2026-10-28).
///
/// The status comes from the server, which derives it from the profile on
/// every read. The app never decides on its own that someone is verified.
class VerifyHubPage extends ConsumerWidget {
  const VerifyHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verification = ref.watch(verificationProvider);

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Verify',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      child: verification.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(verificationProvider),
        ),
        data: (v) {
          final gold = v.tier == VerificationTier.gold;
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 22, 0, 40),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.titleGutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconPlate(
                      v.verified ? Icons.verified : Icons.verified_outlined,
                      size: 52,
                      radius: 16,
                      background: gold ? AppColors.goldSoft : AppColors.blueSoft,
                      foreground: gold ? AppColors.gold : AppColors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _title(v),
                      style: AppText.title1.copyWith(fontSize: 27, height: 33 / 27),
                    ),
                    const SizedBox(height: 8),
                    Text(_body(v), style: AppText.callout),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
              SectionGroup(
                children: [
                  AppRow(
                    label: 'DigiLocker',
                    // Said here because this is where someone decides whether
                    // to tap, and "do I have to download something" is what
                    // stops them. It opens in the browser: there is no app.
                    subtitle: v.inIndia || v.digilocker.verified
                        ? _subtitle(
                            v.digilocker,
                            ready: 'No app needed. It opens in your browser.',
                            outdated:
                                'Your name or date of birth changed. Verify again.',
                          )
                        : 'For people living in India',
                    leading: const Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: AppColors.blue,
                    ),
                    onTap: v.inIndia && _open(v.digilocker)
                        ? () => context.push(Routes.digilocker)
                        : null,
                  ),
                  AppRow(
                    label: 'Selfie',
                    subtitle: _subtitle(
                      v.selfie,
                      ready: 'Checked against your profile photos.',
                      outdated: 'Your photos changed. Take a new selfie.',
                    ),
                    leading: const Icon(
                      Icons.face_retouching_natural_outlined,
                      size: 18,
                      color: AppColors.blue,
                    ),
                    last: true,
                    onTap: _open(v.selfie) ? () => context.push(Routes.selfie) : null,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Insets.titleGutter),
                child: NoteCard(
                  icon: Icons.lock_outline,
                  text: 'Others see only the tick, never your details or your '
                      'selfie. Change your name or date of birth, or add a '
                      'photo, and that check goes until you do it again.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// A check can be started when it is switched on, not already standing,
  /// and not taken away by our team.
  static bool _open(Check c) =>
      c.available && !c.verified && c.status != VerificationStatus.revoked;

  static String? _subtitle(
    Check c, {
    required String ready,
    required String outdated,
  }) {
    if (c.verified) return 'Done';
    if (c.status == VerificationStatus.revoked) return 'Removed by our team';
    if (!c.available) return 'Not available right now';
    if (c.status == VerificationStatus.outdated) return outdated;
    return ready;
  }

  String _title(Verification v) {
    if (v.tier == VerificationTier.gold) return 'You are verified twice.';
    if (v.verified) return 'You are verified.';
    if (v.digilocker.status == VerificationStatus.revoked ||
        v.selfie.status == VerificationStatus.revoked) {
      return 'Verification removed.';
    }
    if (v.digilocker.status == VerificationStatus.outdated ||
        v.selfie.status == VerificationStatus.outdated) {
      return 'Verify again.';
    }
    return 'Show people you are real.';
  }

  String _body(Verification v) {
    if (v.tier == VerificationTier.gold) {
      return 'Your profile carries the gold tick: your name and age match '
          'your Aadhaar, and your photos match your selfie.';
    }
    if (v.digilocker.verified) {
      return 'Your profile carries a blue tick: your name and age match your '
          'Aadhaar. Take a selfie as well for the gold tick.';
    }
    if (v.selfie.verified) {
      return v.inIndia
          ? 'Your profile carries a blue tick: your photos match your '
              'selfie. Verify with DigiLocker as well for the gold tick.'
          : 'Your profile carries a blue tick: your photos match your '
              'selfie.';
    }
    if (v.digilocker.status == VerificationStatus.revoked ||
        v.selfie.status == VerificationStatus.revoked) {
      return 'Our team removed your verification. Write to us from Settings '
          'if you think that is a mistake.';
    }
    if (v.digilocker.status == VerificationStatus.outdated ||
        v.selfie.status == VerificationStatus.outdated) {
      return 'Something on your profile changed after you verified, so the '
          'tick is off until you check it again.';
    }
    if (!v.inIndia) {
      return 'A selfie gives you a blue tick. It takes a few seconds. '
          'DigiLocker is only for people living in India.';
    }
    return 'Either check gives you a blue tick, and both give you gold. '
        'DigiLocker takes about a minute; a selfie takes a few seconds.';
  }
}
