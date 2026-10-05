import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/platform.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'pressable.dart';

enum AppTab { home, chats, you }

/// The one place the two platforms genuinely diverge.
///
/// **iOS** floats a glass bar inset from the edges with the wall scrolling
/// under it — the profile stays the screen, and the bar is a layer on top.
///
/// **Android** docks it to the bottom edge, opaque, above the gesture bar,
/// which is where every Android bottom bar lives. The glass is dropped: a
/// translucent bar sitting directly on the system navigation bar reads as a
/// rendering mistake rather than a material.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.current,
    required this.onSelect,
    this.chatsBadge = 0,
    this.onHoldHome,
    this.blind = false,
    super.key,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final int chatsBadge;

  /// Holding Home turns it over to Go blind, and holding it again turns it
  /// back. There is no fourth tab: Blind is Home's other face.
  final VoidCallback? onHoldHome;

  /// Home is showing Go blind, so it reads Blind under the sparkle.
  final bool blind;

  /// The bar itself, without the safe area under it.
  static const barHeight = 62.0;

  /// The gap the floating bar keeps between itself and the safe area.
  static const _floatingInset = 6.0;

  /// How much room the bar takes above the bottom safe area.
  ///
  /// Anything floating over the same screen has to clear this, and the number
  /// belongs here rather than in each of them: the shell sets `extendBody`, so
  /// content runs underneath the bar on both platforms, and a page that guesses
  /// drifts the day this bar changes height. Measured from the same origin a
  /// page inside [AppScaffold] gets, which is already inside the safe area, so
  /// it is the same figure on a phone with a home indicator and one without.
  static double get clearance =>
      AppPlatform.floatingTabBar ? barHeight + _floatingInset : barHeight;

  @override
  Widget build(BuildContext context) {
    return AppPlatform.floatingTabBar ? _floating(context) : _docked(context);
  }

  /// Liquid glass, drawn rather than borrowed from UIKit so the bar stays
  /// this app's bar on every iOS version: the wall behind is blurred and
  /// saturated, the edge is lit from the top left, and the selected tab sits
  /// on a lens that slides, and stretches as it goes, from tab to tab.
  ///
  /// Increase Contrast swaps the clear glass for the frosted one, which is
  /// what that setting asks of every translucent surface.
  Widget _floating(BuildContext context) {
    final clear = !MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(barHeight / 2);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        MediaQuery.paddingOf(context).bottom + _floatingInset,
      ),
      child: DecoratedBox(
        // Outside the clip, or the clip cuts it away.
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: AppColors.liquidShadow,
              blurRadius: 34,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: clear
                ? ImageFilter.compose(outer: _blur, inner: _saturate)
                : _blur,
            child: CustomPaint(
              painter: _GlassPainter(
                fill: clear ? AppColors.liquidGlass : AppColors.glass,
                sheen: AppColors.liquidSheen,
              ),
              child: SizedBox(
                height: barHeight,
                child: Stack(
                  children: [
                    Positioned.fill(child: _lens(context)),
                    _items(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static final _blur = ImageFilter.blur(sigmaX: 24, sigmaY: 24);

  /// Saturation 1.6: colour behind the glass comes through richer, not
  /// greyer, which is most of what separates liquid glass from frosted.
  static const _saturate = ColorFilter.matrix(<double>[
    1.4724, -0.4291, -0.0433, 0, 0, //
    -0.1276, 1.1709, -0.0433, 0, 0, //
    -0.1276, -0.4291, 1.5567, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// How far the lens sits in from the bar's edge.
  static const _lensInset = 5.0;

  /// The lens moves on its own curve, not [Ease.emphasised]: it overshoots
  /// and settles back, which is what makes it read as liquid rather than as a
  /// highlight sliding along a rail.
  static const _lensCurve = Cubic(0.34, 1.36, 0.64, 1);
  static const _lensTravel = Duration(milliseconds: 420);

  Widget _lens(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final slot = box.maxWidth / AppTab.values.length;
        return TweenAnimationBuilder<double>(
          tween: Tween(end: current.index.toDouble()),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : _lensTravel,
          curve: _lensCurve,
          builder: (context, at, _) {
            // 0 at rest on a tab, .5 halfway between two: the lens is widest
            // mid-travel, the way a drop stretches when it is pulled.
            final pull = (at - at.round()).abs();
            final width = slot - _lensInset * 2 + slot * 0.5 * pull;
            return Stack(
              children: [
                Positioned(
                  left: slot * (at + 0.5) - width / 2,
                  top: _lensInset,
                  bottom: _lensInset,
                  width: width,
                  child: const CustomPaint(
                    painter: _GlassPainter(fill: AppColors.liquidLens),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _docked(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.row,
        border: Border(
          top: BorderSide(color: AppColors.separator, width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(height: barHeight, child: _items()),
    );
  }

  Widget _items() {
    return Row(
      children: [
        _item(
          AppTab.home,
          blind ? 'Blind' : 'Home',
          blind ? Icons.auto_awesome : Icons.home_rounded,
          onLongPress: onHoldHome,
        ),
        _item(AppTab.chats, 'Chats', Icons.forum_rounded, badge: chatsBadge),
        _item(AppTab.you, 'You', Icons.account_circle_outlined),
      ],
    );
  }

  Widget _item(
    AppTab tab,
    String label,
    IconData icon, {
    int badge = 0,
    VoidCallback? onLongPress,
  }) {
    final on = tab == current;
    return Expanded(
      child: Pressable(
        onTap: () => onSelect(tab),
        onLongPress: onLongPress,
        semanticLabel: label,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Home's icon turns over with the screen: house to
                  // sparkle and back.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: RotationTransition(
                        turns: Tween(begin: 0.5, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Icon(
                      icon,
                      key: ValueKey(icon),
                      size: 22,
                      color: on ? AppColors.accent : AppColors.label3,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 15),
                        height: 15,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.destructive,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$badge',
                          style: AppText.micro.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.label,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              // Home's label turns over with its icon, so the two do not
              // change at different moments.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: Text(
                  label,
                  key: ValueKey(label),
                  style: AppText.tabLabel.copyWith(
                    color: on ? AppColors.accent : AppColors.label3,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pill of glass: its tint, an optional sheen over the top half, and a rim
/// lit from the top left that fades out along the bottom right — the light
/// catching the edge, rather than a border drawn around it.
class _GlassPainter extends CustomPainter {
  const _GlassPainter({required this.fill, this.sheen});

  final Color fill;
  final Color? sheen;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pill = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.shortestSide / 2),
    );

    canvas.drawRRect(pill, Paint()..color = fill);

    if (sheen != null) {
      canvas.drawRRect(
        pill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sheen!, sheen!.withValues(alpha: 0)],
            stops: const [0, 0.5],
          ).createShader(rect),
      );
    }

    canvas.drawRRect(
      pill.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.liquidRimLit,
            AppColors.liquidRimShade,
            AppColors.liquidRimShade,
            AppColors.liquidRimLit,
          ],
          // Lit hard at the top left, faintly again at the bottom right where
          // the light would exit.
          stops: [0, 0.35, 0.75, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill || old.sheen != sheen;
}
