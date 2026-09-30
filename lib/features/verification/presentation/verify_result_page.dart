import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';

/// DigiLocker's outcome.
///
/// DigiLocker is instant, and this screen is only reached after the server
/// said `verified`: the tick is the server's, never something awarded here.
class VerifyResultPage extends ConsumerWidget {
  const VerifyResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: const AppNavBar(),
      footer: Column(
        children: [
          PrimaryButton(
            label: 'See your profile',
            onPressed: () => context.go(Routes.editProfile),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Done',
            onPressed: () => context.go(Routes.home),
          ),
        ],
      ),
      child: const ResultScaffoldBody(
        mark: ResultMark(icon: Icons.check, filled: true),
        title: 'Verified.',
        body: 'Your name and date of birth match your Aadhaar. Your profile '
            'now carries a blue tick.',
        note: NoteCard(
          text: 'Change the first name or date of birth on your profile '
              'and the tick goes until you verify again.',
        ),
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
