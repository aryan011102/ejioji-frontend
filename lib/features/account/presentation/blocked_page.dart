import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/models/person.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// Everyone this person has blocked, from the server.
///
/// Lifting a block only lets the two back into each other's feeds. What the
/// block ended (a match, a conversation, a request) stays ended, and the
/// footer says so.
class BlockedPage extends ConsumerStatefulWidget {
  const BlockedPage({super.key});

  @override
  ConsumerState<BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends ConsumerState<BlockedPage> {
  String? _lifting;

  static String _since(DateTime at) {
    final day = dayLabel(at);
    return switch (day) {
      'Today' || 'Yesterday' => 'Blocked ${day.toLowerCase()}',
      _ => 'Blocked on $day',
    };
  }

  Future<void> _unblock(BlockedPerson person) async {
    final name = person.firstName ?? 'them';
    final choice = await showAppActionSheet(
      context,
      title: 'Unblock $name?',
      message: 'You may see each other in the feed again. The old chat does '
          'not come back.',
      actions: const [SheetAction('Unblock')],
    );
    if (choice != 0 || !mounted) return;

    setState(() => _lifting = person.userId);
    try {
      await ref.read(matchingRepositoryProvider).unblock(person.userId);
      if (!mounted) return;
      ref.invalidate(blockedProvider);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _lifting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(blockedProvider);

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Blocked',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      child: blocked.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(blockedProvider),
        ),
        data: (people) => people.isEmpty
            ? const EmptyState(
                icon: Icons.block,
                title: 'Nobody is blocked',
                body: 'You can block anyone from their profile or from inside a '
                    'chat.',
              )
            : ListView(
                padding: const EdgeInsets.only(top: 18, bottom: 40),
                children: [
                  SectionGroup(
                    footer: "A blocked person can't find you, see your profile "
                        'or write to you. They are never told, and unblocking '
                        'does not restore the chat.',
                    children: [
                      for (final person in people)
                        AppRow(
                          label: person.firstName ?? 'Someone',
                          subtitle: _since(person.blockedAt),
                          last: person == people.last,
                          leading: Avatar(
                            seedColor: const Color(0xFF8E7B93),
                            imageUrl: person.photo?.stillUrl,
                            size: 29,
                          ),
                          control: MiniButton(
                            label: 'Unblock',
                            tone: MiniTone.quiet,
                            busy: _lifting == person.userId,
                            onPressed:
                                _lifting == null ? () => _unblock(person) : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
