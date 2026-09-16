import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

class BlockedPage extends ConsumerStatefulWidget {
  const BlockedPage({super.key});

  @override
  ConsumerState<BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends ConsumerState<BlockedPage> {
  final _blocked = <(String, String, Color)>[
    ('Someone you blocked', 'Blocked on 2 September', const Color(0xFF8E7B93)),
    ('Another account', 'Blocked on 21 August', const Color(0xFF7B8E88)),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Blocked',
        backLabel: 'Settings',
        onBack: () => context.pop(),
      ),
      child: _blocked.isEmpty
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
                    for (final (name, since, seed) in _blocked)
                      AppRow(
                        label: name,
                        subtitle: since,
                        last: name == _blocked.last.$1,
                        leading: Avatar(seedColor: seed, size: 29),
                        control: MiniButton(
                          label: 'Unblock',
                          tone: MiniTone.quiet,
                          // TODO(backend): DELETE Api.block(userId).
                          onPressed: () => setState(
                            () => _blocked.removeWhere((b) => b.$1 == name),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
