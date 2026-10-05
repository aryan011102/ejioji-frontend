import 'dart:ui' show ImageFilter;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/foundation.dart';
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
/// From iOS 26 that bar is Apple's own, in Liquid Glass; before it, ours.
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

  /// iOS 26 and later get Apple's own bar, so the glass is the real Liquid
  /// Glass rather than a drawing of it. Checked in this order so the web
  /// build never asks for an OS version, which it cannot read.
  static bool get _appleGlass =>
      AppPlatform.floatingTabBar &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      PlatformVersion.isIOS26OrLater;

  @override
  Widget build(BuildContext context) {
    if (_appleGlass) return _native(context);
    return AppPlatform.floatingTabBar ? _floating(context) : _docked(context);
  }

  /// Apple's tab bar: a real UITabBar hosted in the tree, with its own lens,
  /// motion and badge.
  ///
  /// It claims every touch that lands on it, so it has no way to tell a tap
  /// from a hold, and holding Home is how Blind is reached. A Flutter layer
  /// therefore sits over Home's third of the bar and handles both itself: a
  /// tap selects Home, which the bar then animates to like any other change,
  /// and a hold turns Home over. Chats and You are Apple's untouched.
  Widget _native(BuildContext context) {
    final bar = CNTabBar(
      tint: AppColors.accent,
      currentIndex: current.index,
      onTap: (i) => onSelect(AppTab.values[i]),
      items: [
        CNTabBarItem(
          label: blind ? 'Blind' : 'Home',
          icon: CNSymbol(blind ? 'sparkles' : 'house'),
          activeIcon: CNSymbol(blind ? 'sparkles' : 'house.fill'),
        ),
        CNTabBarItem(
          label: 'Chats',
          icon: const CNSymbol('bubble.left.and.bubble.right'),
          activeIcon: const CNSymbol('bubble.left.and.bubble.right.fill'),
          badge: chatsBadge > 0 ? '$chatsBadge' : null,
        ),
        const CNTabBarItem(
          label: 'You',
          icon: CNSymbol('person.crop.circle'),
          activeIcon: CNSymbol('person.crop.circle.fill'),
        ),
      ],
    );

    return SafeArea(
      top: false,
      // Centred and shrink-wrapped, so the overlay's third is a third of the
      // bar Apple draws and not of the screen.
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Stack(
          children: [
            bar,
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 1 / AppTab.values.length,
                // The bar reads Home to VoiceOver itself; this layer is only
                // for fingers.
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(AppTab.home),
                    onLongPress: onHoldHome,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floating(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        MediaQuery.paddingOf(context).bottom + _floatingInset,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(31),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(31),
              border: Border.all(color: AppColors.glassEdge),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x38000000),
                  blurRadius: 34,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: _items(),
          ),
        ),
      ),
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
