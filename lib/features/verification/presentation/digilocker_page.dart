import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';

/// What will be asked, and what is never shared, before anything opens.
///
/// Someone about to sign in to a government service with their Aadhaar-linked
/// number deserves to know the shape of the request first. Saying it after the
/// handoff is saying it too late.
class DigilockerStepsPage extends ConsumerWidget {
  const DigilockerStepsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'DigiLocker',
        backLabel: 'Verify',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Continue to DigiLocker',
        icon: const Icon(
          Icons.open_in_new,
          size: 16,
          color: AppColors.onAccent,
        ),
        onPressed: () => context.push(Routes.digilockerHandoff),
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
            title: 'Approve two fields',
            body: 'Your name and your date of birth. That is the whole request '
                '— your Aadhaar number is never shared with theonebytwo.',
            last: true,
          ),
          const SizedBox(height: 26),
          const NoteCard(
            icon: Icons.lock_outline,
            text: 'DigiLocker is run by the Government of India. theonebytwo never '
                'sees your password or your OTP.',
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
/// a phishing app does. All this screen does is say where you are going.
///
/// The real implementation opens the URL in the system browser — never a
/// WebView we control, which could read what is typed into it.
class DigilockerHandoffPage extends ConsumerStatefulWidget {
  const DigilockerHandoffPage({super.key});

  @override
  ConsumerState<DigilockerHandoffPage> createState() =>
      _DigilockerHandoffPageState();
}

class _DigilockerHandoffPageState extends ConsumerState<DigilockerHandoffPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // TODO(backend): POST Api.digilockerStart, launch the returned URL
    // externally, then wait for the deep link back and POST
    // Api.digilockerFinish. This timer stands in for that round trip.
    _timer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) context.pushReplacement(Routes.digilockerDone);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
                "digilocker.gov.in will open. Finish there and you'll come "
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
