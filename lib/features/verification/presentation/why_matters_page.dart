import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/layout.dart';

/// One page, three entrances: the outline tick on your own profile, the locked
/// chat button on home, and the banner on the chats list.
///
/// It is prose rather than a list because the questions it answers — who sees
/// the selfie, how long it is kept — are the ones that stop people, and a
/// bulleted reassurance reads like a terms page.
class WhyMattersPage extends ConsumerWidget {
  const WhyMattersPage({super.key});

  static const _sections = <(String, String)>[
    (
      'What the blue tick means',
      'One of two things was checked: either a government ID says you are who '
          'you say, or a live selfie says the photos on this profile are of '
          'you. Either is enough to start a conversation.',
    ),
    (
      'What the gold tick means',
      'Both. An ID and a photo. It gives no extra features and no better '
          'placement — it exists because this is the question a family asks '
          'first, and it deserves an answer that took more than a minute to '
          'earn.',
    ),
    (
      'What we never see',
      'DigiLocker shares your name and date of birth with us and nothing else. '
          'Your Aadhaar number never reaches ejioji. The selfie is used for the '
          'check and deleted after it, and it is never shown to another person '
          '— not to matches, not to families, not on your profile.',
    ),
    (
      'Why chat waits for it',
      'Anyone can write to anyone here, which is unusual and worth protecting. '
          'The check is what makes it safe to leave open: it costs a real '
          'person two minutes and costs someone running twenty fake profiles '
          'far more than that.',
    ),
    (
      'If a check fails',
      'Nothing happens to your profile and nobody is told. You can try again, '
          'or use the other route. A failed check is almost always a bad photo '
          'rather than a bad person.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Why this matters',
        backLabel: 'Verify',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.titleGutter,
          22,
          Insets.titleGutter,
          40,
        ),
        children: [
          Text(
            'A tick is a small promise, kept carefully.',
            style: AppText.title1.copyWith(fontSize: 27, height: 33 / 27),
          ),
          const SizedBox(height: 20),
          for (final (heading, body) in _sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: AppText.title3.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: AppText.callout.copyWith(height: 22 / 15),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
