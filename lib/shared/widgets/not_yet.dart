import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'states.dart';

/// For the parts of this app the backend does not have yet.
///
/// Several screens were designed and built before the API existed, and the API
/// grew in a different direction: there is no billing, no verification, no
/// profile-views counter and no pause. Those screens are kept, because the
/// design work in them is real and the features are still wanted, but they say
/// so rather than showing placeholder content.
///
/// The rule is narrow: **never render invented data.** A screen that shows
/// three fake people who viewed your profile is indistinguishable from one
/// that works, right up until someone trusts it.
class NotYet extends StatelessWidget {
  const NotYet({
    required this.title,
    required this.body,
    this.icon = Icons.construction_rounded,
    super.key,
  });

  /// What this screen will do, stated in the present tense, because it is a
  /// description of the feature rather than an apology.
  final String title;

  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: title,
      body: body,
      extra: const _NotConnectedChip(),
    );
  }
}

/// The inline version, for a screen that is otherwise real and has one part
/// that is not wired.
class NotYetNote extends StatelessWidget {
  const NotYetNote({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.titleGutter,
        4,
        Insets.titleGutter,
        12,
      ),
      child: NoteCard(text: text, icon: Icons.construction_rounded),
    );
  }
}

class _NotConnectedChip extends StatelessWidget {
  const _NotConnectedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.fill2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Not built yet',
        style: AppText.micro.copyWith(color: AppColors.label3),
      ),
    );
  }
}
