import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

/// Two different nothings, and they need two different answers.
///
/// One is caused by the person and is fixable in ten seconds; the other is
/// caused by the city and is not fixable at all — so the second must never
/// look like a failure, and must not ask for anything.
enum EmptyFeedKind { filtered, seenEveryone }

class EmptyFeedPage extends ConsumerWidget {
  const EmptyFeedPage({required this.kind, super.key});

  final EmptyFeedKind kind;

  static const _activeFilters = [
    'Men',
    '26–34',
    'Mumbai',
    "Master's",
    'English, Hindi',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = kind == EmptyFeedKind.filtered;

    return AppScaffold(
      navBar: AppNavBar(backLabel: 'Home', onBack: () => context.pop()),
      child: EmptyState(
        icon: filtered ? Icons.search_off : Icons.schedule,
        title: filtered
            ? 'Nobody matches all five.'
            : "That's everyone for now.",
        body: filtered
            ? 'Together these are narrow. Loosening any one of them usually '
                'brings people back.'
            : "You've seen every profile that matches. People join every day — "
                'this fills back up on its own.',
        // Naming the filters beats telling someone to go and look at them.
        extra: filtered
            ? Wrap(
                alignment: WrapAlignment.center,
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final f in _activeFilters)
                    AppChip(label: f, selected: false),
                ],
              )
            : const NoteCard(
                icon: Icons.chat_bubble_outline,
                text: 'Nothing is waiting on you here. The people who wrote to '
                    'you are still in Chats.',
              ),
        primaryLabel: filtered ? 'Change filters' : 'Widen your filters',
        onPrimary: () => context.push(Routes.filters),
        secondaryLabel: filtered ? 'Reset to default' : null,
        onSecondary: filtered ? () => context.pop() : null,
      ),
    );
  }
}
