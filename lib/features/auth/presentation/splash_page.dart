import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';

/// The first screen, and the only one that renders while the keychain is read.
///
/// It shows the value of the product in one line rather than a spinner,
/// because the read is fast and a spinner on a cold start looks like a stall.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(sessionProvider).stage;
    final settled = stage != SessionStage.unknown;

    return AppScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text('theonebytwo', style: AppText.largeTitle.copyWith(fontSize: 44)),
            const SizedBox(height: 14),
            Text(
              'A profile built from what you already did, not what you would '
              'like to claim.',
              style: AppText.callout.copyWith(fontSize: 19, height: 26 / 19),
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: settled ? 1 : 0,
              duration: Motion.fade,
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Get started',
                    onPressed:
                        settled ? () => context.push(Routes.phone) : null,
                  ),
                  const SizedBox(height: 6),
                  TextActionButton(
                    label: 'I already have an account',
                    onPressed:
                        settled ? () => context.push(Routes.phone) : null,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'By continuing you agree to the Terms and the Privacy '
                      'Policy.',
                      textAlign: TextAlign.center,
                      style: AppText.micro,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
