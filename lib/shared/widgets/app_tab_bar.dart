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
    super.key,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final int chatsBadge;

  @override
  Widget build(BuildContext context) {
    return AppPlatform.floatingTabBar ? _floating(context) : _docked(context);
  }

  Widget _floating(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        MediaQuery.paddingOf(context).bottom + 6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(31),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 62,
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
      child: SizedBox(height: 62, child: _items()),
    );
  }

  Widget _items() {
    return Row(
      children: [
        _item(AppTab.home, 'Home', Icons.home_rounded),
        _item(AppTab.chats, 'Chats', Icons.forum_rounded, badge: chatsBadge),
        _item(AppTab.you, 'You', Icons.account_circle_outlined),
      ],
    );
  }

  Widget _item(AppTab tab, String label, IconData icon, {int badge = 0}) {
    final on = tab == current;
    return Expanded(
      child: Pressable(
        onTap: () => onSelect(tab),
        semanticLabel: label,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: on ? AppColors.accent : AppColors.label3,
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
              Text(
                label,
                style: AppText.tabLabel.copyWith(
                  color: on ? AppColors.accent : AppColors.label3,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
