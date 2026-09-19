import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/tiles.dart';

/// Friends get the profile as it is; family get the same person collated.
enum SharedAudience { friends, family }

/// The page a friend or a parent opens.
///
/// **Each link opens the other person's profile** — a parent is shown the
/// person their child has been talking to, not their own child.
///
/// Reached from inside the app here, so it carries a back that names where it
/// goes. A parent who was forwarded the link is in their own browser and
/// already has one; the app cannot draw that and should not pretend to.
class SharedProfilePage extends ConsumerWidget {
  const SharedProfilePage({
    required this.audience,
    this.fromChat = true,
    super.key,
  });

  final SharedAudience audience;
  final bool fromChat;

  /// A category of insights becomes one sentence about a person, with the
  /// number left underneath as quiet evidence. "27 biryani orders" is a fact
  /// about an app; "knows exactly what to order" is a fact about a person.
  ///
  /// A model writes these from the same insights the profile already holds —
  /// nobody hand-curates, and there is no per-insight "fine for family" mark.
  static const _traits = <(String, String, String, String)>[
    (
      '🍚',
      'Knows exactly what to order',
      'A biryani loyalist with one kitchen he has stayed with for years, and a '
          'weekly Tuesday habit at the same table.',
      'From 312 food orders',
    ),
    (
      '🏃',
      'Up before the city is',
      'Runs most mornings, usually the same loop, and has kept it up through a '
          'Bengaluru December.',
      '1,204 km this year',
    ),
    (
      '🎧',
      'Listens widely',
      'Ghazals next to techno, and the same handful of songs on repeat when '
          'the day has been long.',
      '41,203 minutes · Spotify',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = audience == SharedAudience.family;
    final slug = family ? 'family/rohan-8f21' : 'r/rohan-8f21';

    return AppScaffold(
      child: Column(
        children: [
          if (fromChat) _InAppBar(onClose: () => context.pop()),
          _AddressBar(slug: slug),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    6,
                    Insets.gutter,
                    0,
                  ),
                  child: Text(
                    'ANANYA SHARED THIS WITH YOU',
                    style: AppText.groupHeader.copyWith(letterSpacing: 0.4),
                  ),
                ),
                family ? _familyHeader() : _friendsHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    18,
                    Insets.gutter,
                    0,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment:
                        family ? WrapAlignment.start : WrapAlignment.center,
                    children: [
                      for (final (icon, label) in Demo.pills)
                        FactPill(icon: icon, label: label),
                    ],
                  ),
                ),
                if (family) ..._collated() else _wall(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    24,
                    Insets.gutter,
                    0,
                  ),
                  child: NoteCard(
                    text: family
                        ? 'This page belongs to ${Demo.themFirst}, and was '
                            'shared deliberately. It holds no contact details, '
                            'no social accounts and no way to message anyone. '
                            'There is nothing here to download: either of them '
                            'can withdraw it, and the page stops working when '
                            'they do.'
                        : "This is ${Demo.themFirst}'s profile as it stands on "
                            'theonebytwo — nothing added, nothing taken out. It '
                            'holds no contact details, no social accounts and '
                            'no way to message anyone.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The app's own header: circle, name, solid tick.
  Widget _friendsHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 16, Insets.gutter, 0),
        child: Column(
          children: [
            const Avatar(seedColor: Demo.themSeed, size: 96),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Demo.themName,
                  style: AppText.title1.copyWith(fontSize: 26),
                ),
                const SizedBox(width: 8),
                const VerifiedTick(tier: VerificationTier.blue, size: 19),
              ],
            ),
          ],
        ),
      );

  /// The tick gets a full line of its own: to this audience it is the single
  /// most reassuring thing on the page.
  Widget _familyHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 14, Insets.gutter, 0),
        child: Row(
          children: [
            const PhotoFrame(
              seedColor: Demo.themSeed,
              width: 104,
              height: 132,
              radius: 18,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Demo.themName,
                    style: AppText.title1.copyWith(fontSize: 27),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const VerifiedTick(tier: VerificationTier.blue),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Photo verified\nby theonebytwo',
                          style: AppText.footnote.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /// The friends page shows the wall tile for tile — nothing collated, nothing
  /// softened, because a friend is being asked *what do you think* and a
  /// filtered profile makes that unanswerable.
  Widget _wall() => BentoGrid(
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          22,
          Insets.gutter,
          0,
        ),
        children: [
          for (final t in Demo.wall)
            BentoItem(
              size: t.size,
              child: InsightTile(
                size: t.size,
                number: t.number,
                caption: t.caption,
                prompt: t.prompt,
                answer: t.answer,
                tone: t.tone,
                hasMedia: t.media,
                isTrack: t.track,
              ),
            ),
        ],
      );

  List<Widget> _collated() => [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            26,
            Insets.gutter,
            12,
          ),
          child: Text(
            'WHAT THE EVERYDAY LOOKS LIKE',
            style: AppText.groupHeader.copyWith(letterSpacing: 0.4),
          ),
        ),
        for (final (glyph, title, body, note) in _traits)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              0,
              Insets.gutter,
              10,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.row,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.fill2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(glyph, style: const TextStyle(fontSize: 17)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.bodyStrong),
                        const SizedBox(height: 3),
                        Text(
                          body,
                          style: AppText.footnote.copyWith(fontSize: 13.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          note,
                          style: AppText.micro.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ];
}

class _InAppBar extends StatelessWidget {
  const _InAppBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Pressable(
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chevron_left,
                    size: 26,
                    color: AppColors.accent,
                  ),
                  Text(
                    'Chat',
                    style: AppText.navAction.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Pressable(
            onTap: onClose,
            semanticLabel: 'Close',
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                color: AppColors.fill2,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.label2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A visible URL is most of what stops a parent wondering what they have been
/// sent.
class _AddressBar extends StatelessWidget {
  const _AddressBar({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 13, color: AppColors.label3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'theonebytwo.com/$slug',
                overflow: TextOverflow.ellipsis,
                style: AppText.footnote.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
