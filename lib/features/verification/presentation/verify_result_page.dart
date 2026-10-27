import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';

/// The two ways to the tick.
enum VerifyRoute {
  digilocker('DigiLocker'),
  selfie('Selfie check');

  const VerifyRoute(this.title);

  final String title;
}

/// Either check's outcome, one screen.
///
/// Both are instant, and this screen is only reached after the server said
/// `verified`: the tick is the server's, never something awarded here.
/// [tier] is the server's answer after this check, so a person who already
/// had the other one sees gold straight away. DigiLocker's answer does not
/// carry it, so without one it is read from the profile, which completing
/// the check reloads.
class VerifyResultPage extends ConsumerWidget {
  const VerifyResultPage({required this.route, this.tier, super.key});

  final VerifyRoute route;
  final VerificationTier? tier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = (tier ?? ref.watch(myProfileProvider).valueOrNull?.tier) ==
        VerificationTier.gold;
    final checked = switch (route) {
      VerifyRoute.digilocker => 'Your name and date of birth match your Aadhaar.',
      VerifyRoute.selfie => 'Your selfie matches the photos on your profile.',
    };

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
      child: ResultScaffoldBody(
        mark: const ResultMark(icon: Icons.check, filled: true),
        title: 'Verified.',
        body: gold
            ? '$checked With both checks done, your profile now carries the '
                'gold tick.'
            : '$checked Your profile now carries a blue tick.',
        note: NoteCard(
          text: switch (route) {
            VerifyRoute.digilocker =>
              'Change the first name or date of birth on your profile and the '
                  'tick goes until you verify again.',
            VerifyRoute.selfie =>
              'Add or replace a photo on your profile and the selfie tick goes '
                  'until you take a new one. The selfie itself was not kept.',
          },
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
    this.route = VerifyRoute.digilocker,
    this.fixable = false,
  });

  final String title;

  /// The server's own words where it gave some, so the app never guesses at
  /// what DigiLocker or the face check said.
  final String body;

  final VerifyRoute route;

  /// The check answered and something on the profile did not agree (a name,
  /// a birth date, a photo), so the way forward is to edit the profile, not
  /// to try the check again as it is.
  final bool fixable;
}

/// One error screen for both checks.
///
/// Neither kind of failure is the person's fault, so neither is red. When the
/// profile disagreed the way out is editing it; otherwise it is trying again.
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
    final selfie = f.route == VerifyRoute.selfie;

    return AppScaffold(
      navBar: AppNavBar(
        title: f.route.title,
        backLabel: 'Verify',
        onBack: () => context.pop(),
      ),
      footer: Column(
        children: [
          if (f.fixable)
            PrimaryButton(
              label: selfie ? 'Edit your photos' : 'Edit your profile',
              onPressed: () => context.pushReplacement(Routes.editInfo),
            )
          else
            PrimaryButton(
              label: 'Try again',
              onPressed: () => context.pushReplacement(
                selfie ? Routes.selfie : Routes.digilocker,
              ),
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
        note: NoteCard(
          text: selfie
              ? 'Nothing on your profile changed, nobody is told, and the '
                  'selfie was not kept.'
              : 'Nothing on your profile changed, nobody is told, and we kept '
                  'nothing DigiLocker sent.',
        ),
      ),
    );
  }
}
