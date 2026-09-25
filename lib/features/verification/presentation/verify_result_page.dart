import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';

enum VerifyRoute { digilocker, selfie }

/// Two outcomes, one screen.
///
/// DigiLocker is instant, and this screen is only reached after the server
/// said `verified`: the tick is the server's, never something awarded here.
/// The selfie version describes a review that is not built yet; nothing links
/// to it until the selfie check exists.
class VerifyResultPage extends ConsumerWidget {
  const VerifyResultPage({required this.route, super.key});

  final VerifyRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instant = route == VerifyRoute.digilocker;

    return AppScaffold(
      navBar: const AppNavBar(),
      footer: Column(
        children: [
          PrimaryButton(
            label: instant ? 'See your profile' : 'Back to browsing',
            onPressed: () =>
                instant ? context.go(Routes.editProfile) : context.go(Routes.home),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Done',
            onPressed: () => context.go(Routes.home),
          ),
        ],
      ),
      child: ResultScaffoldBody(
        mark: ResultMark(
          icon: instant ? Icons.check : Icons.face_retouching_natural_outlined,
          filled: instant,
        ),
        title: instant ? 'Verified.' : 'Under review.',
        body: instant
            ? 'Your name and date of birth match your Aadhaar. Your profile '
                'now carries a blue tick.'
            : "Usually within 24 hours, and we'll tell you either way. Nothing "
                'else changes meanwhile: you can browse, and people can still '
                'write to you.',
        note: instant
            ? const NoteCard(
                text: 'Change the first name or date of birth on your profile '
                    'and the tick goes until you verify again.',
              )
            : null,
      ),
    );
  }
}

/// Why a check did not end in a tick, handed to [VerifyErrorPage].
class VerifyFailure {
  const VerifyFailure({
    required this.title,
    required this.body,
    this.fixable = false,
  });

  final String title;

  /// The server's own words where it gave some, so the app never guesses at
  /// what DigiLocker said.
  final String body;

  /// DigiLocker answered and something on the profile did not agree, so the
  /// way forward is to edit the profile, not to wait for DigiLocker.
  final bool fixable;
}

/// One error screen for DigiLocker.
///
/// Neither kind of failure is the person's fault, so neither is red. When the
/// profile disagreed with Aadhaar the way out is editing it; when DigiLocker
/// did not answer, it is trying again.
class VerifyErrorPage extends ConsumerWidget {
  const VerifyErrorPage({this.failure, super.key});

  final VerifyFailure? failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = failure ??
        const VerifyFailure(
          title: "DigiLocker didn't respond.",
          body: 'The site was unreachable, or the sign-in was cancelled '
              'before it finished.',
        );

    return AppScaffold(
      navBar: AppNavBar(
        title: 'DigiLocker',
        backLabel: 'Verify',
        onBack: () => context.pop(),
      ),
      footer: Column(
        children: [
          if (f.fixable)
            PrimaryButton(
              label: 'Edit your profile',
              onPressed: () => context.pushReplacement(Routes.editInfo),
            )
          else
            PrimaryButton(
              label: 'Try again',
              onPressed: () => context.pushReplacement(Routes.digilocker),
            ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Not now',
            onPressed: () => context.go(Routes.home),
          ),
        ],
      ),
      child: ResultScaffoldBody(
        mark: const ResultMark(icon: Icons.warning_amber_rounded, size: 76),
        title: f.title,
        body: f.body,
        note: const NoteCard(
          text: 'Nothing on your profile changed, nobody is told, and we kept '
              'nothing DigiLocker sent.',
        ),
      ),
    );
  }
}
