import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/not_yet.dart';

/// Verification, which the backend does not do yet.
///
/// The design is two routes to one door: a DigiLocker check or a live selfie,
/// either of which earns the tick, and both of which earn gold. None of it has
/// an endpoint, a moderation queue or a third-party integration behind it, so
/// this screen says so rather than pretending.
///
/// The screens for both routes are still in this repository
/// (`digilocker_page.dart`, `selfie_page.dart`, `verify_result_page.dart`) and
/// are still routed. They are simply not linked from here, because a flow that
/// ends in nothing is worse than a flow that has not started.
///
/// This gap matters more than it looks. Without a liveness check the app fills
/// with stolen photos, which is fatal to a matrimonial product and far harder
/// to retrofit than to build.
class VerifyHubPage extends ConsumerWidget {
  const VerifyHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Verify',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      child: const NotYet(
        icon: Icons.verified_outlined,
        title: 'Verification is not switched on yet.',
        body: 'Two ways are planned: a DigiLocker check of your name and date '
            'of birth, or a live selfie. Neither is connected to anything yet, '
            'so nobody carries a tick and chat is not gated on one.',
      ),
    );
  }
}
