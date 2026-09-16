import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';

const _groups = <(String, List<(String, String)>)>[
  ('Food and delivery', [('Swiggy', 'Order history'), ('Zomato', 'Same inbox')]),
  ('Listening', [('Spotify', 'Top tracks, minutes, genres')]),
  (
    'Moving',
    [('Apple Health', 'Steps and workouts'), ('Strava', 'Runs and rides')]
  ),
  ('Watching', [('YouTube', 'Watch history, channels')]),
  (
    'Socials',
    [('Instagram', 'Handle only'), ('LinkedIn', 'Work and education')]
  ),
];

/// What the profile is actually made of.
///
/// The promise on this screen is the product's whole premise, so it is stated
/// once at the top and never repeated per row: we read the pattern, never the
/// contents.
class ConnectAccountsPage extends ConsumerStatefulWidget {
  const ConnectAccountsPage({super.key});

  @override
  ConsumerState<ConnectAccountsPage> createState() =>
      _ConnectAccountsPageState();
}

class _ConnectAccountsPageState extends ConsumerState<ConnectAccountsPage> {
  final _linked = <String>{'Spotify'};

  @override
  Widget build(BuildContext context) {
    final count = _linked.length;
    return AppScaffold(
      navBar: AppNavBar(backLabel: 'Back', onBack: () => context.pop()),
      footer: PrimaryButton(
        label: count == 0
            ? 'Connect at least one'
            : 'Read $count account${count > 1 ? 's' : ''}',
        onPressed: count == 0 ? null : () => context.push(Routes.reading),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const LargeTitle(
            'Complete your profile',
            subtitle: 'Connect what you use. We read the pattern, never the '
                'contents — no messages, no addresses, no card numbers, ever.',
          ),
          for (final (header, apps) in _groups)
            SectionGroup(
              header: header,
              children: [
                for (final (name, note) in apps)
                  AppRow(
                    label: name,
                    subtitle: note,
                    last: name == apps.last.$1,
                    control: MiniButton(
                      label: _linked.contains(name) ? 'Linked' : 'Connect',
                      tone: _linked.contains(name)
                          ? MiniTone.quiet
                          : MiniTone.filled,
                      icon: _linked.contains(name)
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.ok,
                            )
                          : null,
                      // TODO(backend): each of these is an OAuth handoff. The
                      // client never sees the provider's credentials — it opens
                      // the provider's own sheet and the backend exchanges the
                      // code.
                      onPressed: () => setState(
                        () => _linked.contains(name)
                            ? _linked.remove(name)
                            : _linked.add(name),
                      ),
                    ),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.titleGutter,
            ),
            child: Text(
              'You can unlink any of these later, and anything already on your '
              'profile stays until you take it off.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
