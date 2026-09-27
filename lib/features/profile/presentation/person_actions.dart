import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/providers.dart';
import '../../../shared/models/person.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';

/// What you can do to somebody else's profile from its top bar: keep it, or
/// the "···" sheet. Shared by Home, whose bar floats over the profile, and a
/// pushed profile, whose bar is its own, so the two cannot drift.

/// The bookmark. Filled when this person is in your saved list.
///
/// Saving is Premium; the server says so with `premium_required`, and then the
/// Premium page opens instead of a toast. Removing is always allowed.
class SaveProfileButton extends ConsumerWidget {
  const SaveProfileButton({required this.person, super.key});

  final Candidate person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref.watch(savedProvider).valueOrNull?.has(person.userId) ?? false;
    return NavIconButton(
      icon: saved ? Icons.bookmark : Icons.bookmark_border,
      semanticLabel: saved
          ? 'Remove ${person.firstName} from saved'
          : 'Save ${person.firstName}',
      onTap: () => _toggle(context, ref, saved: saved),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required bool saved,
  }) async {
    final repo = ref.read(matchingRepositoryProvider);
    try {
      if (saved) {
        await repo.unsave(person.userId);
      } else {
        await repo.save(person.userId);
      }
      ref.invalidate(savedProvider);
      if (!context.mounted) return;
      showAppToast(
        context,
        saved
            ? '${person.firstName} is no longer saved.'
            : '${person.firstName} is saved. They are never told.',
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'premium_required') {
        unawaited(context.push<void>(Routes.premium));
      } else {
        showAppToast(context, e.message);
      }
    }
  }
}

/// Report or block. [onBlocked] is what the screen does once they are gone:
/// the deck moves to the next card, a pushed profile goes back.
Future<void> showPersonMenu(
  BuildContext context,
  WidgetRef ref,
  Candidate person, {
  required VoidCallback onBlocked,
}) async {
  final choice = await showAppActionSheet(
    context,
    message: '${person.firstName} is never told either way.',
    actions: [
      const SheetAction('Report profile', destructive: true),
      SheetAction('Block ${person.firstName}', destructive: true),
    ],
  );
  if (!context.mounted) return;

  if (choice == 0) {
    unawaited(
      context.push<void>(
        Routes.reportFor(person.userId, name: person.firstName),
      ),
    );
  } else if (choice == 1) {
    try {
      // Blocking is two-way and immediate: it ends any match, declines a
      // pending request in either direction, and takes them out of both
      // feeds.
      await ref.read(matchingRepositoryProvider).block(person.userId);
      ref.invalidate(savedProvider);
      if (!context.mounted) return;
      showAppToast(context, '${person.firstName} is blocked.');
      onBlocked();
    } on ApiException catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    }
  }
}

/// A glyph in a top bar, in the accent colour, with a touch target larger than
/// the glyph.
class NavIconButton extends StatelessWidget {
  const NavIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.size = 22,
    this.child,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double size;

  /// Drawn instead of the plain icon, for one that carries a dot.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: child ?? Icon(icon, size: size, color: AppColors.accent),
      ),
    );
  }
}
