import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/tiles.dart';
import 'arrange_wall.dart';

/// Where this screen was reached from. It changes the foot and nothing else.
enum ProfileMode {
  /// The end of setup: there is a next, and it is the rest of onboarding.
  review,

  /// From the account tab: no next, so two doors instead.
  owner,

  /// Somebody else's, which is what home is.
  viewer,
}

/// The profile, all three ways it is seen.
///
/// One component rather than three screens, because they are the same wall
/// with different feet — and a copy of a wall is a wall that drifts.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({required this.mode, super.key});

  final ProfileMode mode;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _arranging = false;
  List<String> _order = Demo.wall.map((t) => t.id).toList();

  /// Nothing on this screen writes until Save — arranging included. Two save
  /// rules on one screen is how people lose work.
  bool _dirty = false;

  bool get _viewer => widget.mode == ProfileMode.viewer;

  /// Moving a tile puts it where the target sits and shuffles the rest along,
  /// which is what a person expects from dragging one card onto another.
  void _reorder(String moved, String target) {
    setState(() {
      final next = [..._order]..remove(moved);
      next.insert(next.indexOf(target), moved);
      _order = next;
      _dirty = true;
    });
  }

  Future<void> _verifySheet() async {
    final choice = await showAppActionSheet(
      context,
      title: 'Verify your profile',
      message: 'Two ways — a government ID through DigiLocker, or a selfie. '
          'Either one opens chat and gives you a tick. Doing both gives the '
          'gold one.',
      actions: const [
        SheetAction('Verify profile'),
        SheetAction('Why it matters'),
      ],
    );
    if (choice != null && mounted) context.push(Routes.verify);
  }

  Future<void> _moreSheet() async {
    final choice = await showAppActionSheet(
      context,
      message: '${Demo.themFirst} is never told either way.',
      actions: const [
        SheetAction('Report profile', destructive: true),
        SheetAction('Block ${Demo.themFirst}', destructive: true),
      ],
    );
    if (!mounted) return;
    if (choice == 0) {
      unawaited(context.push<void>(Routes.reportFor('c1')));
    } else if (choice == 1) {
      // TODO(backend): POST Api.block(userId).
      showAppToast(context, '${Demo.themFirst} is blocked.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final tiles = _order
        .map((id) => Demo.wall.firstWhere((t) => t.id == id))
        .toList();
    final columnsUsed =
        tiles.fold<int>(0, (sum, t) => sum + t.size.columns);

    return AppScaffold(
      navBar: _topBar(context),
      footer: _viewer ? null : _foot(context),
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: _viewer ? 210 : 24),
            children: [
              _header(session),
              _pills(),
              if (!_viewer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.titleGutter,
                    14,
                    Insets.titleGutter,
                    0,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 15,
                        color: AppColors.label3,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'This is the profile as everyone else sees it.',
                        style: AppText.caption.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              if (_arranging)
                ArrangeWall(
                  order: _order,
                  onReorder: _reorder,
                  onRemove: (id) => setState(() {
                    _order.remove(id);
                    _dirty = true;
                  }),
                  onFloorHit: () => showAppToast(
                    context,
                    'Six is the fewest a profile can show. Add another before '
                    'taking one off.',
                  ),
                )
              else
                BentoGrid(
                  children: [
                    for (final t in tiles)
                      BentoItem(
                        size: t.size,
                        child: InsightTile(
                          size: t.size,
                          number: t.number,
                          caption: t.caption,
                          prompt: t.prompt,
                          answer: t.answer,
                          tone: t.tone,
                          hasMedia: t.media,
                          isTrack: t.track,
                          // The source glyph is for the owner sorting their own
                          // wall. A viewer is being introduced to a person and
                          // does not need a filing system on the photos.
                          categoryGlyph: _viewer ? null : t.glyph,
                        ),
                      ),
                    BentoItem(
                      size: columnsUsed.isOdd ? TileSize.small : TileSize.wide,
                      child: const PhotosTile(photos: Demo.photos),
                    ),
                  ],
                ),
            ],
          ),
          if (_viewer) _viewerActions(context, session),
        ],
      ),
    );
  }

  PreferredSizeWidget _topBar(BuildContext context) {
    if (_viewer) {
      return AppNavBar(
        backLabel: null,
        trailingLabel: '···',
        onTrailing: _moreSheet,
      );
    }
    return AppNavBar(
      backLabel: widget.mode == ProfileMode.owner ? 'You' : 'Back',
      onBack: () => context.pop(),
      trailingLabel: _arranging ? 'Done' : 'Arrange',
      onTrailing: () => setState(() => _arranging = !_arranging),
    );
  }

  Widget _header(Session session) {
    final name = _viewer ? Demo.themName : Demo.meName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 4, Insets.gutter, 0),
      child: Row(
        children: [
          Avatar(
            seedColor: _viewer ? Demo.themSeed : Demo.meSeed,
            size: 74,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title1.copyWith(fontSize: 26),
                      ),
                    ),
                    const SizedBox(width: 7),
                    VerifiedTick(
                      tier: _viewer ? VerificationTier.blue : session.tier,
                      onTap: _viewer ? null : _verifySheet,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      _viewer ? 'he/him' : 'she/her',
                      style: AppText.footnote.copyWith(fontSize: 14),
                    ),
                    if (!_viewer) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: AppColors.accent,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 16, Insets.gutter, 0),
      child: Row(
        children: [
          for (final (icon, label) in Demo.pills) ...[
            FactPill(icon: icon, label: label),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _foot(BuildContext context) {
    if (widget.mode == ProfileMode.review) {
      return Row(
        children: [
          const Expanded(child: SecondaryButton(label: 'Edit profile')),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: 'Save and next',
              onPressed: () {
                ref.read(sessionProvider.notifier).onProfileCreated();
                context.go(Routes.home);
              },
            ),
          ),
        ],
      );
    }

    if (_dirty) {
      return Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Discard',
              onPressed: () => setState(() => _dirty = false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: 'Save changes',
              onPressed: () => setState(() => _dirty = false),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            label: 'Edit info',
            onPressed: () => context.push(Routes.editInfo),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SecondaryButton(
            label: 'Edit insights',
            onPressed: () => context.push(Routes.editSources),
          ),
        ),
      ],
    );
  }

  /// Pass is never gated; chat is. The locked button is a door rather than a
  /// dead end — it looks locked, says why, and opens the way through.
  Widget _viewerActions(BuildContext context, Session session) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            60,
            Insets.gutter,
            100,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), AppColors.group],
              stops: [0, 0.62],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!session.canChat) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 13, color: AppColors.label3),
                    const SizedBox(width: 8),
                    Text(
                      'Verify to start chatting. Two ways, either one works.',
                      style: AppText.caption.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Pressable(
                    onTap: () => context.push(Routes.feedEmptySeen),
                    semanticLabel: 'Pass',
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.row,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 22,
                        color: AppColors.label2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: session.canChat
                        ? PrimaryButton(
                            label: 'Chat with ${Demo.themFirst}',
                            onPressed: () => context.push(
                              Routes.conversationWith('c1'),
                            ),
                          )
                        : SecondaryButton(
                            label: 'Chat with ${Demo.themFirst}',
                            icon: const Icon(
                              Icons.lock,
                              size: 14,
                              color: AppColors.label2,
                            ),
                            onPressed: _verifySheet,
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
