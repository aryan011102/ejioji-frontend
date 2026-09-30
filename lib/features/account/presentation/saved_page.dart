import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

/// People you saved with the bookmark on their profile, newest first. Premium.
///
/// Reached from the bookmark on your own profile. Opening someone here gives
/// their profile a "Chat with" button, since this list is where you come back
/// to ask.
///
/// The list is checked on the server every time, as the views list is: someone
/// who has since blocked you, stopped showing or left your filters is not here.
/// Nobody is ever told they were saved.
class SavedPage extends ConsumerWidget {
  const SavedPage({this.backLabel = 'Profile', super.key});

  /// The screen behind: your profile's bookmark or the You tab.
  final String backLabel;

  static String _when(DateTime at) => switch (dayLabel(at)) {
        'Today' || 'Yesterday' => 'Saved ${dayLabel(at).toLowerCase()}',
        final day => 'Saved on $day',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvider);

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Saved',
        backLabel: backLabel,
        onBack: () => context.pop(),
      ),
      child: saved.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(savedProvider),
        ),
        data: (list) => list.locked
            ? ListView(
                padding: const EdgeInsets.only(top: 18, bottom: 40),
                children: [
                  const SectionGroup(
                    footer: 'Keep someone to come back to later. They are '
                        'never told. Anyone you saved before is kept for when '
                        'you have onebytwo plus again.',
                    children: [
                      AppRow(
                        label: 'Saved profiles are part of onebytwo plus',
                        last: true,
                      ),
                    ],
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Insets.gutter),
                    child: PrimaryButton(
                      label: "See what's in onebytwo plus",
                      onPressed: () => context.push(Routes.premium),
                    ),
                  ),
                ],
              )
            : list.saved.isEmpty
            ? const EmptyState(
                icon: Icons.bookmark_border,
                title: 'Nobody saved yet',
                body: 'Tap the bookmark at the top of a profile to keep '
                    'them here. They are never told.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(savedProvider.future),
                child: ListView(
                  padding: const EdgeInsets.only(top: 18, bottom: 40),
                  children: [
                    SectionGroup(
                      footer: 'Only you can see this list.',
                      children: [
                        for (final s in list.saved)
                          AppRow(
                            label: '${s.person.displayName}, ${s.person.age}',
                            subtitle: _when(s.savedAt),
                            last: s == list.saved.last,
                            leading: Avatar(
                              seedColor: const Color(0xFF8E7B93),
                              imageUrl: s.person.photos.firstOrNull?.stillUrl,
                              size: 29,
                            ),
                            onTap: () => context.push(
                              Routes.person,
                              extra: PersonArgs(
                                person: s.person,
                                backLabel: 'Saved',
                                canAsk: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
