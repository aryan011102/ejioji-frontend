import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/not_yet.dart';

/// Profile views, which nothing records yet.
///
/// The design was a free count with the faces blurred behind Premium. Both
/// halves need something the backend does not have: it logs an impression when
/// a card is *shown in a feed*, which is not the same as someone opening your
/// profile, and there is no billing to gate the faces behind.
///
/// The previous version of this screen listed four invented people and a made
/// up weekly total. That is the one thing this screen must not do: a fake
/// viewer is indistinguishable from a real one, and the blur made it look
/// deliberate.
class ProfileViewsPage extends ConsumerWidget {
  const ProfileViewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Profile views',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      child: const NotYet(
        icon: Icons.visibility_outlined,
        title: 'Nobody is counting views yet.',
        body: 'When this is switched on it will show how many people opened '
            'your profile. Nothing is being recorded in the meantime, so '
            'there is no number to show you.',
      ),
    );
  }
}
