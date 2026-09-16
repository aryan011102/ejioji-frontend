import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';

enum VerifyRoute { digilocker, selfie }

/// Two outcomes, one screen.
///
/// DigiLocker is instant; the selfie is with a person for a day. The pending
/// version says what still works meanwhile, because the worst reading of
/// "under review" is that the account has been suspended.
class VerifyResultPage extends ConsumerStatefulWidget {
  const VerifyResultPage({required this.route, super.key});

  final VerifyRoute route;

  @override
  ConsumerState<VerifyResultPage> createState() => _VerifyResultPageState();
}

class _VerifyResultPageState extends ConsumerState<VerifyResultPage> {
  @override
  void initState() {
    super.initState();
    if (widget.route == VerifyRoute.digilocker) {
      // Instant, so the tier moves as the screen appears. The selfie does not:
      // it is still with a reviewer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final current = ref.read(sessionProvider).tier;
          ref.read(sessionProvider.notifier).onVerified(
                current == VerificationTier.blue
                    ? VerificationTier.gold
                    : VerificationTier.blue,
              );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final instant = widget.route == VerifyRoute.digilocker;

    return AppScaffold(
      navBar: const AppNavBar(),
      footer: Column(
        children: [
          PrimaryButton(
            label: instant ? 'Add the selfie check' : 'Back to browsing',
            onPressed: () => instant
                ? context.pushReplacement(Routes.selfie)
                : context.go(Routes.home),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: instant ? 'Not now' : 'Done',
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
            ? 'Your name and date of birth match your ID. Your profile carries '
                'a blue tick, and chat is open.'
            : "Usually within 24 hours, and we'll tell you either way. Nothing "
                'else changes meanwhile — you can browse, and people can still '
                'write to you.',
        note: instant
            ? const NoteCard(
                tone: NoteTone.gold,
                text: 'Add a selfie check for the gold tick. Two minutes, and '
                    'it says both an ID and a photo were verified.',
              )
            : null,
      ),
    );
  }
}

/// One error screen, two wordings.
///
/// Neither failure is the person's fault — a DigiLocker outage, or bad light —
/// so neither is red, and both offer the *other route* rather than only a
/// retry.
class VerifyErrorPage extends ConsumerWidget {
  const VerifyErrorPage({required this.route, super.key});

  final VerifyRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final digi = route == VerifyRoute.digilocker;

    return AppScaffold(
      navBar: AppNavBar(
        title: digi ? 'DigiLocker' : 'Selfie check',
        backLabel: 'Verify',
        onBack: () => context.pop(),
      ),
      footer: Column(
        children: [
          PrimaryButton(
            label: 'Try again',
            onPressed: () => context.pop(),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: digi ? 'Use the selfie check' : 'Use DigiLocker',
            onPressed: () => context.pushReplacement(
              digi ? Routes.selfie : Routes.digilocker,
            ),
          ),
          Center(
            child: TextActionButton(label: 'Get help', onPressed: () {}),
          ),
        ],
      ),
      child: ResultScaffoldBody(
        mark: const ResultMark(icon: Icons.warning_amber_rounded, size: 76),
        title: digi ? "DigiLocker didn't respond." : "That didn't match.",
        body: digi
            ? 'The site was unreachable, or the sign-in was cancelled before it '
                'finished. Nothing was shared, and nothing on your profile '
                'changed.'
            : 'Usually the light, or a hand not quite where the pose asked. '
                'Nothing on your profile changed and nobody is told.',
        note: NoteCard(
          text: digi
              ? 'If it keeps failing, DigiLocker may be down — it happens. The '
                  'selfie check takes two minutes and works just as well.'
              : 'Try somewhere brighter, facing a window. Or use DigiLocker '
                  'instead, which takes about a minute.',
        ),
      ),
    );
  }
}
