import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

/// Two different nothings, and they need two different answers.
///
/// One is caused by the person and is fixable in ten seconds; the other is
/// caused by the city and is not fixable at all, so the second must never look
/// like a failure and must not ask for anything.
enum EmptyFeedKind { filtered, seenEveryone }

class EmptyFeedPage extends ConsumerWidget {
  const EmptyFeedPage({required this.kind, this.onRetry, super.key});

  final EmptyFeedKind kind;

  /// Home passes this so "look again" rebuilds the deck in place. It is null
  /// when the screen is reached as its own route, where going back is the way
  /// out.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = kind == EmptyFeedKind.filtered;
    // The real filters, read from the server. Naming them beats telling
    // somebody to go and look at them, and inventing a plausible list would
    // send people to widen filters they never set.
    final preferences = ref.watch(preferencesProvider).valueOrNull;

    final chips = <String>[
      if (preferences != null) ...[
        for (final g in preferences.showGenders) g.label,
        if (preferences.ageMin != null && preferences.ageMax != null)
          '${preferences.ageMin} to ${preferences.ageMax}',
      ],
    ];

    return AppScaffold(
      navBar: onRetry == null
          ? AppNavBar(backLabel: 'Home', onBack: () => context.pop())
          : const AppNavBar(),
      child: EmptyState(
        icon: filtered ? Icons.search_off : Icons.schedule,
        title: filtered
            ? 'Nobody matches yet.'
            : 'That is everyone for now.',
        body: filtered
            ? 'Widening any one of these usually brings people back. We are '
                'also opening one city at a time, so there may simply not be '
                'many people here yet.'
            : 'You have seen every profile that matches. People join every '
                'day, so this fills back up on its own.',
        extra: filtered && chips.isNotEmpty
            ? Wrap(
                alignment: WrapAlignment.center,
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final f in chips) AppChip(label: f, selected: false),
                ],
              )
            : const NoteCard(
                icon: Icons.chat_bubble_outline,
                text: 'Nothing is waiting on you here. Anyone who asked to '
                    'chat is still in Chats.',
              ),
        primaryLabel: filtered ? 'Change filters' : 'Look again',
        onPrimary: filtered
            ? () => context.push(Routes.filters)
            : (onRetry ?? () => context.pop()),
        secondaryLabel: filtered && onRetry != null ? 'Look again' : null,
        onSecondary: filtered ? onRetry : null,
      ),
    );
  }
}
