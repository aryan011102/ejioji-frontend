import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/layout.dart';

/// Unread rows carry a dot rather than a tint — a wall of highlighted rows
/// tells you nothing.
///
/// The copy quotes the insight rather than announcing an event, because a
/// notification about a profile built from insights should sound like one.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static const _items = <(String, String, String, String, bool)>[
    (
      '💬',
      'Rohan replied',
      '"Which place? I have opinions about paneer rolls."',
      '2m',
      true
    ),
    ('👀', 'Someone opened your profile', 'Your third view today', '1h', true),
    (
      '✅',
      'Your photo check went through',
      'You can chat now',
      'Yesterday',
      false
    ),
    (
      '🎧',
      'Spotify has something new',
      "Two months of listening we hadn't read",
      'Mon',
      false
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Notifications',
        backLabel: 'Home',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          SectionGroup(
            children: [
              for (final (glyph, title, body, at, unread) in _items)
                AppRow(
                  label: title,
                  subtitle: body,
                  last: title == _items.last.$2,
                  leading: Text(glyph, style: const TextStyle(fontSize: 16)),
                  control: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(at, style: AppText.caption.copyWith(fontSize: 12.5)),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 9,
                        height: 9,
                        child: unread
                            ? const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.fill,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
