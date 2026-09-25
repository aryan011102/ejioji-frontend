import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../data/verify_controller.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';
import 'verify_result_page.dart';

/// What will be asked, and what is never shared, before anything opens.
///
/// Someone about to sign in to a government service with their Aadhaar-linked
/// number deserves to know the shape of the request first. Saying it after the
/// handoff is saying it too late.
class DigilockerStepsPage extends ConsumerStatefulWidget {
  const DigilockerStepsPage({super.key});

  @override
  ConsumerState<DigilockerStepsPage> createState() =>
      _DigilockerStepsPageState();
}

class _DigilockerStepsPageState extends ConsumerState<DigilockerStepsPage> {
  bool _checking = false;

  /// Consent first, always. The server refuses to start a check without an
  /// open identity_verification grant, so asking here is the only order that
  /// works, and the notice's words are the server's.
  Future<void> _continue() async {
    setState(() => _checking = true);
    try {
      final consent = await ref.read(consentProvider.future);
      if (!mounted) return;
      if (!consent.isGranted(ConsentPurpose.identityVerification)) {
        final granted = await context.push<bool>(
          '${Routes.consent}?purpose=${ConsentPurpose.identityVerification.wire}',
        );
        if (granted != true || !mounted) return;
        ref.invalidate(consentProvider);
      }
      await context.push(Routes.digilockerHandoff);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'DigiLocker',
        backLabel: 'Verify',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Continue to DigiLocker',
        busy: _checking,
        icon: const Icon(
          Icons.open_in_new,
          size: 16,
          color: AppColors.onAccent,
        ),
        onPressed: _checking ? null : _continue,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.titleGutter,
          22,
          Insets.titleGutter,
          40,
        ),
        children: [
          const IconPlate(
            Icons.description_outlined,
            size: 52,
            radius: 16,
            background: AppColors.blueSoft,
            foreground: AppColors.blue,
          ),
          const SizedBox(height: 16),
          Text(
            'Two steps, about a minute.',
            style: AppText.title1.copyWith(fontSize: 27, height: 33 / 27),
          ),
          const SizedBox(height: 8),
          Text(
            "You'll finish this on DigiLocker's own site and come straight "
            'back.',
            style: AppText.callout,
          ),
          const SizedBox(height: 26),
          const StepRow(
            number: '1',
            title: 'Sign in to DigiLocker',
            body: 'With the mobile number linked to your Aadhaar. The OTP '
                'comes from DigiLocker, not from us.',
          ),
          const StepRow(
            number: '2',
            title: 'Allow theonebytwo',
            body: 'DigiLocker asks to share your profile details. We compare '
                'your name and date of birth with your profile and keep '
                'neither. Your Aadhaar number is never shared with us.',
            last: true,
          ),
          const SizedBox(height: 26),
          const NoteCard(
            icon: Icons.lock_outline,
            text: 'DigiLocker is run by the Government of India. theonebytwo '
                'never sees your password or your OTP.',
          ),
        ],
      ),
    );
  }
}

/// The handoff.
///
/// Deliberately **not** a drawing of DigiLocker's own screen: that page belongs
/// to them, and imitating a government login inside our chrome is exactly what
/// a phishing app does. All this screen does is say where you are going, open
/// it in the system browser, and wait for the link back.
class DigilockerHandoffPage extends ConsumerStatefulWidget {
  const DigilockerHandoffPage({super.key});

  @override
  ConsumerState<DigilockerHandoffPage> createState() =>
      _DigilockerHandoffPageState();
}

class _DigilockerHandoffPageState extends ConsumerState<DigilockerHandoffPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final result = await ref.read(verifyProvider.notifier).begin();
      if (!mounted) return;
      if (result == null || result.declined) {
        // They came back without finishing, or said no on DigiLocker's
        // screen. An answer, not a failure: nothing was shared.
        showAppToast(context, 'Verification was cancelled. Nothing was shared.');
        context.pop();
        return;
      }
      if (result.verified) {
        context.pushReplacement(Routes.digilockerDone);
        return;
      }
      context.pushReplacement(
        Routes.verifyFailed,
        extra: VerifyFailure(
          title: switch (result.outcome) {
            'not_aadhaar' => 'Not linked to Aadhaar.',
            'identity_in_use' => 'Already verifying someone.',
            _ => 'That did not match.',
          },
          body: result.message,
          // Only a mismatch is fixed on the profile; the others are not.
          fixable: result.outcome == 'birth_date_differs' ||
              result.outcome == 'name_differs' ||
              result.outcome == 'no_profile',
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      context.pushReplacement(
        Routes.verifyFailed,
        extra: VerifyFailure(title: "DigiLocker didn't respond.", body: e.message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: const AppNavBar(title: 'DigiLocker'),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accent,
                  backgroundColor: AppColors.fill2,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Taking you to DigiLocker',
                textAlign: TextAlign.center,
                style: AppText.title3,
              ),
              const SizedBox(height: 6),
              Text(
                "DigiLocker will open. Finish there and you'll come "
                'straight back.',
                textAlign: TextAlign.center,
                style: AppText.callout.copyWith(fontSize: 14.5),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: AppColors.label3,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Government of India',
                    style: AppText.caption.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
