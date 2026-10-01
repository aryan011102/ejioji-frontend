import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
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

    return AppScaffold(
      navBar: onRetry == null
          ? AppNavBar(backLabel: 'Home', onBack: () => context.pop())
          : const AppNavBar(),
      child: EmptyState(
        icon: filtered ? Icons.search_off : Icons.schedule,
        // Filtered: the title alone (Aryan, 2026-10-01); the buttons below
        // already say what to do about it.
        title: filtered ? 'No people nearby.' : 'That is everyone for now.',
        body: filtered
            ? null
            : 'You have seen every profile that matches. People join every '
                'day, so this fills back up on its own.',
        extra: filtered
            ? null
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
