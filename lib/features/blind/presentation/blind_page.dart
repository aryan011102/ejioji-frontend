import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/blind_controller.dart';
import '../../../data/providers.dart';
import '../../../shared/models/blind.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/app_tab_bar.dart';
import '../../../shared/widgets/ask_about_sheet.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';
import '../../home/presentation/home_page.dart' show feedMissingStep;
import 'blind_field.dart';
import 'blind_layout.dart';

/// Go blind: Home turned over.
///
/// Home is a person at a time: you meet them, then their tiles. This is the
/// other way in. A plane of single tiles from many people, with nothing on
/// them that says whose, which you drag any way you like. You find someone by
/// a line of theirs that stops you, and tapping it is when they stop being
/// anonymous. The people are the same as Home's: the server deals from the
/// feed's own slate, in shuffled order.
class BlindPage extends ConsumerStatefulWidget {
  const BlindPage({super.key});

  @override
  ConsumerState<BlindPage> createState() => _BlindPageState();
}

class _BlindPageState extends ConsumerState<BlindPage>
    with SingleTickerProviderStateMixin {
  static const _hintKey = 'blind.drag_hint_seen';

  BlindLayout? _layout;
  int _layoutDeal = -1;

  /// The shuffle button's one turn.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  bool _hint = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeShowHint());
    // Your own profile, held while Blind is up, so "Chat about this" knows
    // whether you are verified when the sheet opens. Read cold, it is still
    // loading and the sheet would say "Send request" to someone who can't.
    ref.listenManual(myProfileProvider, (_, __) {});
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  /// "Drag any way you like", once, ever. It answers the only question a
  /// plane raises, which is which way, and the answer is any.
  Future<void> _maybeShowHint() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_hintKey) ?? false) return;
    await prefs.setBool(_hintKey, true);
    if (mounted) setState(() => _hint = true);
  }

  void _shuffle() {
    HapticFeedback.lightImpact();
    unawaited(_spin.forward(from: 0));
    unawaited(ref.read(blindProvider.notifier).shuffle());
  }

  /// The layout follows the deal: a new deal is a new plane, more of the same
  /// deal is added to the one in hand.
  BlindLayout _layoutFor(BlindState state) {
    final current = _layout;
    if (current == null || _layoutDeal != state.deal) {
      _layoutDeal = state.deal;
      return _layout = BlindLayout(state.tiles);
    }
    if (state.tiles.length > current.length) {
      current.add(state.tiles.sublist(current.length));
    }
    return current;
  }

  void _open(BlindTile t) => context.push(
        Routes.person,
        extra: PersonArgs(person: t.person, backLabel: 'Blind', canAsk: true),
      );

  Future<void> _chat(BlindTile t) async {
    final blind = ref.read(blindProvider.notifier);
    final name = t.person.firstName;
    await showAskAboutSheet(
      context,
      name: name,
      tile: t.tile,
      send: (note) async {
        final result = await blind.ask(t.person, t.tile, note: note);
        return result.accepted
            ? '$name asked you too. The chat opens on this tile.'
            : 'Asked about this. $name will see it with your request.';
      },
    // Unknown (the profile has not loaded) counts as verified: the server is
    // the real gate and refuses with verification_required, which the sheet
    // then handles. Guessing the other way would stop a verified person.
      verified: ref.read(myProfileProvider).valueOrNull?.verified ?? true,
      onVerify: () => context.push(Routes.verify),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blindProvider);
    final padding = MediaQuery.paddingOf(context);
    const stripHeight = 56.0;
    final top = padding.top + stripHeight;

    return ColoredBox(
      color: AppColors.group,
      child: Stack(
        children: [
          Positioned.fill(child: _body(state, top)),
          // The plane has no edges of its own, so the screen lends it some:
          // tiles fade out under the chrome rather than being sliced by it.
          _EdgeFade(top: true, height: top + 28),
          _EdgeFade(top: false, height: AppTabBar.clearance + padding.bottom + 70),
          Positioned(
            left: 0,
            right: 0,
            top: padding.top,
            child: _CategoryTabs(
              categories: state.categories,
              selected: state.category,
              onSelect: (c) =>
                  unawaited(ref.read(blindProvider.notifier).choose(c)),
            ),
          ),
          Positioned(
            right: Insets.gutter,
            bottom: padding.bottom + AppTabBar.clearance + 16,
            child: _ShuffleButton(spin: _spin, onTap: _shuffle),
          ),
          if (_hint && state.tiles.isNotEmpty)
            const Align(alignment: Alignment(0, 0.1), child: _Hint()),
        ],
      ),
    );
  }

  Widget _body(BlindState state, double top) {
    if (state.loading || !state.started) return _Dealing(top: top);

    final error = state.error;
    if (error != null) {
      final step = feedMissingStep(error);
      if (step != null) {
        return EmptyState(
          icon: step.icon,
          title: step.title,
          body: step.body,
          primaryLabel: step.label,
          onPrimary: () async {
            await context.push<Object?>(step.route);
            await ref.read(blindProvider.notifier).shuffle();
          },
        );
      }
      return ErrorView(
        error: error,
        onRetry: () => ref.read(blindProvider.notifier).shuffle(),
      );
    }

    final category = state.category;
    if (state.tiles.isEmpty) {
      if (category != null) {
        final name = category.label.toLowerCase();
        return EmptyState(
          icon: Icons.search,
          title: 'Nothing in $name right now',
          body: 'Fewer people have a $name tile on their profile than you '
              'would think. It fills up as they add them.',
          primaryLabel: 'Show me everything',
          onPrimary: () => ref.read(blindProvider.notifier).choose(null),
        );
      }
      return EmptyState(
        icon: Icons.auto_awesome,
        title: 'Nobody to go blind on yet',
        body: 'Everyone your filters reach is already in your chats, or '
            'nobody fits them yet. Widen them, or come back later.',
        primaryLabel: 'Filters',
        onPrimary: () => context.push(Routes.filters),
      );
    }

    return GestureDetector(
      // Any touch dismisses the hint: it has done its job the moment someone
      // moves.
      onPanDown: _hint ? (_) => setState(() => _hint = false) : null,
      child: BlindField(
        key: ValueKey(state.deal),
        layout: _layoutFor(state),
        topInset: top + 8,
        asked: state.asked,
        showCategory: category == null,
        onOpen: _open,
        onChat: _chat,
        onRunningLow: () => unawaited(ref.read(blindProvider.notifier).more()),
      ),
    );
  }
}

/// Glass tabs over the top of the plane, not a filter button: filtering is
/// the one thing this page does besides moving, so it is one tap from where
/// the thumb already is.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<TileCategory> categories;
  final TileCategory? selected;
  final ValueChanged<TileCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 10, Insets.gutter, 10),
        children: [
          _GlassTab(
            glyph: '✦',
            label: 'All',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            _GlassTab(
              glyph: c.glyph,
              label: c.label,
              selected: selected == c,
              onTap: () => onSelect(c),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassTab extends StatelessWidget {
  const _GlassTab({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: Motion.fade,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                // Picked goes solid plum; the rest stay glass so the plane
                // reads through them.
                color: selected ? AppColors.fill : AppColors.glass,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? const Color(0x00000000) : AppColors.glassEdge,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(glyph, style: const TextStyle(fontSize: 13.5)),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: AppText.callout.copyWith(
                      fontSize: 14.5,
                      color: selected ? AppColors.onAccent : AppColors.label,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A new deal. It turns once when pressed: the same plane shuffled, said with
/// the button rather than with a spinner.
class _ShuffleButton extends StatelessWidget {
  const _ShuffleButton({required this.spin, required this.onTap});

  final Animation<double> spin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Shuffle',
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.glass,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassEdge),
            ),
            alignment: Alignment.center,
            child: RotationTransition(
              turns: CurvedAnimation(parent: spin, curve: Curves.easeOutBack),
              child: const Icon(
                Icons.shuffle_rounded,
                size: 22,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.top, required this.height});

  final bool top;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: const [AppColors.group, Color(0x00000000)],
              stops: const [0.4, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.glassEdge),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 19,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 9),
                Text(
                  'Tap to open · hold and swipe left to chat',
                  style: AppText.callout.copyWith(
                    color: AppColors.label,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost tiles on the lattice while a deal is on its way: the shape of what
/// is coming is already known, so it is drawn rather than spun.
class _Dealing extends StatelessWidget {
  const _Dealing({required this.top});

  final double top;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geo = BlindGeometry(constraints.maxWidth);
        return ClipRect(
          child: Stack(
            children: [
              for (final (col, row, size) in BlindLayout.slots.take(10))
                Positioned(
                  left: Insets.gutter + col * geo.step,
                  top: top + 8 + row * geo.step,
                  width: geo.box(size).width,
                  height: geo.box(size).height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.fill2,
                      borderRadius: BorderRadius.circular(Radii.tile),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
