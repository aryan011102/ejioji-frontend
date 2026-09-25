import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../data/verification_repository.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

/// Verification: where it stands, and the way to it.
///
/// DigiLocker is live: a check of the profile's first name and date of birth
/// against Aadhaar, which earns the blue tick. The selfie check is not built
/// yet, so it is listed as coming rather than linked: a flow that ends in
/// nothing is worse than one that has not started.
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
        data: (v) => ListView(
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
                    background: AppColors.blueSoft,
                    foreground: AppColors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _title(v.status),
                    style: AppText.title1.copyWith(fontSize: 27, height: 33 / 27),
                  ),
                  const SizedBox(height: 8),
                  Text(_body(v.status), style: AppText.callout),
                  const SizedBox(height: 26),
                ],
              ),
            ),
            SectionGroup(
              children: [
                AppRow(
                  label: 'DigiLocker',
                  subtitle: v.verified
                      ? 'Done. Your name and age match your Aadhaar.'
                      : v.available
                          ? 'Your name and date of birth, about a minute'
                          : 'Not available right now',
                  leading: const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: AppColors.blue,
                  ),
                  onTap: v.verified ||
                          !v.available ||
                          v.status == VerificationStatus.revoked
                      ? null
                      : () => context.push(Routes.digilocker),
                ),
                const AppRow(
                  label: 'Selfie check',
                  subtitle: 'Coming soon',
                  last: true,
                  leading: Icon(
                    Icons.face_retouching_natural_outlined,
                    size: 18,
                    color: AppColors.label3,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.titleGutter),
              child: NoteCard(
                icon: Icons.lock_outline,
                text: 'Others see only the tick, never your details. Change '
                    'the first name or date of birth on your profile and the '
                    'tick goes until you verify again.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(VerificationStatus status) => switch (status) {
        VerificationStatus.verified => 'You are verified.',
        VerificationStatus.outdated => 'Verify again.',
        VerificationStatus.revoked => 'Verification removed.',
        VerificationStatus.none => 'Show people you are real.',
      };

  String _body(VerificationStatus status) => switch (status) {
        VerificationStatus.verified =>
          'Your profile carries a blue tick: DigiLocker agreed with your first '
              'name and date of birth.',
        VerificationStatus.outdated =>
          'Your first name or date of birth changed after you verified, so the '
              'tick is off until DigiLocker agrees with the new one.',
        VerificationStatus.revoked =>
          'Our team removed your verification. Write to us from Settings if '
              'you think that is a mistake.',
        VerificationStatus.none =>
          'A blue tick says your name and age are the ones on your Aadhaar. '
              'It takes about a minute with DigiLocker.',
      };
}
