import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';

/// What "Edit insights" opens — the linking page, not a category.
///
/// Whether an app is connected and which tiles are on the wall are two
/// different questions, and the first is the reason people come: a category
/// that went quiet is an account that stopped. So refresh, unlink and link all
/// live here, and each app opens its own tiles from here.
class EditSourcesPage extends ConsumerStatefulWidget {
  const EditSourcesPage({super.key});

  @override
  ConsumerState<EditSourcesPage> createState() => _EditSourcesPageState();
}

class _EditSourcesPageState extends ConsumerState<EditSourcesPage> {
  final _unlinked = <String>{};
  String? _refreshing;

  Future<void> _refresh(String id) async {
    setState(() => _refreshing = id);
    // TODO(backend): POST Api.sourceRefresh(id). Refresh never blocks the
    // page — re-reading one app has nothing to do with the other five.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) setState(() => _refreshing = null);
  }

  Future<void> _unlink(DemoCategory c) async {
    final choice = await showAppActionSheet(
      context,
      title: 'Unlink ${c.source}?',
      message: 'New insights stop. Anything already on your profile stays '
          'until you drop it yourself.',
      actions: const [SheetAction('Unlink', destructive: true)],
    );
    if (choice == 0 && mounted) setState(() => _unlinked.add(c.id));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Your insights',
        backLabel: 'Profile',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const LargeTitle(
            'Where your profile comes from',
            subtitle: 'Re-read an app, unlink it, or add one. Open any of them '
                'to change which tiles are on your profile.',
          ),
          for (var i = 0; i < Demo.categories.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.gutter,
                0,
                Insets.gutter,
                10,
              ),
              child: _SourceCard(
                category: Demo.categories[i],
                unlinked: _unlinked.contains(Demo.categories[i].id),
                refreshing: _refreshing == Demo.categories[i].id,
                onOpen: () => context.push(Routes.editCategoryAt(i)),
                onRefresh: () => _refresh(Demo.categories[i].id),
                onUnlink: () => _unlink(Demo.categories[i]),
                onLink: () => setState(
                  () => _unlinked.remove(Demo.categories[i].id),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.titleGutter,
            ),
            child: Text(
              'Unlinking stops new insights. Anything already on your profile '
              'stays until you take it off yourself.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two decks: what the app is doing and where its tiles are, then what you can
/// do to the app. "Open tiles" is a hint rather than a third button, because
/// the top deck already is that button.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.category,
    required this.unlinked,
    required this.refreshing,
    required this.onOpen,
    required this.onRefresh,
    required this.onUnlink,
    required this.onLink,
  });

  final DemoCategory category;
  final bool unlinked;
  final bool refreshing;
  final VoidCallback onOpen;
  final VoidCallback onRefresh;
  final VoidCallback onUnlink;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final stale = category.stale && !unlinked;
    final state = unlinked
        ? 'Not linked — nothing from this yet'
        : stale
            ? 'Not read since ${category.lastRead} — reconnect needed'
            : '${category.picked.length} on your profile · '
                'read ${category.lastRead}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.row,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: Column(
          children: [
            PressableRow(
              onTap: unlinked ? null : onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.fill2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        category.glyph,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.source, style: AppText.bodyStrong),
                          const SizedBox(height: 2),
                          Text(
                            state,
                            style: AppText.caption.copyWith(
                              fontSize: 12.5,
                              color: stale
                                  ? AppColors.destructive
                                  : AppColors.label3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!unlinked)
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.label4,
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Divider(
                height: 0.5,
                thickness: 0.5,
                color: AppColors.separator,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              child: unlinked
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: MiniButton(
                        label: 'Link ${category.source}',
                        onPressed: onLink,
                      ),
                    )
                  : Row(
                      children: [
                        MiniButton(
                          label: refreshing ? 'Reading…' : 'Refresh',
                          tone: MiniTone.quiet,
                          icon: const Icon(
                            Icons.refresh,
                            size: 15,
                            color: AppColors.accent,
                          ),
                          onPressed: refreshing ? null : onRefresh,
                        ),
                        const SizedBox(width: 8),
                        MiniButton(
                          label: 'Unlink',
                          tone: MiniTone.destructive,
                          onPressed: onUnlink,
                        ),
                        const Spacer(),
                        Text(
                          'Open tiles',
                          style: AppText.caption.copyWith(
                            fontSize: 12.5,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
