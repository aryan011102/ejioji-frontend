import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

/// The app's waitlist: a new profile waits for the team to take it live.
///
/// Until then the person looks around the app as anyone does, but nobody sees
/// them and they see nobody. The server says so in `publish.waitlisted`, and
/// the feed and Blind answer 403 `waitlisted`. When the team takes them live a
/// push and a live event say so, and the app reads its state again.

const waitlistedTitle = 'Your profile is waitlisted';
const waitlistedWait = 'Approval can take 24–48 hours.';

/// Whether the server refused because this person is still waiting.
bool isWaitlistedError(Object? error) =>
    error is ApiException && error.code == 'waitlisted';

/// Home and Blind while waiting: what is happening, how long it takes, and
/// the one thing worth doing meanwhile.
class WaitlistedState extends StatelessWidget {
  const WaitlistedState({required this.onCompleteProfile, super.key});

  final VoidCallback onCompleteProfile;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.hourglass_empty_rounded,
      title: waitlistedTitle,
      body: '$waitlistedWait Till then, look around.',
      extra: const NoteCard(
        icon: Icons.lightbulb_outline_rounded,
        text: 'Tip: completing your profile helps. Add photos and tiles '
            'while you wait.',
      ),
      primaryLabel: 'Complete my profile',
      onPrimary: onCompleteProfile,
    );
  }
}

/// The You tab and your own profile, while waiting.
class WaitlistedNote extends StatelessWidget {
  const WaitlistedNote({this.padding, super.key});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            Insets.titleGutter,
            4,
            Insets.titleGutter,
            12,
          ),
      child: const NoteCard(
        icon: Icons.hourglass_empty_rounded,
        text: 'Your profile is waitlisted, approval can take 24–48 hours. '
            'No one can see it until then.',
      ),
    );
  }
}

/// A list of other people (Saved, Profile views) while waiting: there is
/// nobody to open yet.
class ProfilesOpenLater extends StatelessWidget {
  const ProfilesOpenLater({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Profiles open once you are approved',
      body: '$waitlistedTitle. $waitlistedWait',
    );
  }
}

/// [WaitlistedState] on a screen of its own, as Home shows it.
class WaitlistedScreen extends StatelessWidget {
  const WaitlistedScreen({required this.onCompleteProfile, super.key});

  final VoidCallback onCompleteProfile;

  @override
  Widget build(BuildContext context) =>
      AppScaffold(child: WaitlistedState(onCompleteProfile: onCompleteProfile));
}
