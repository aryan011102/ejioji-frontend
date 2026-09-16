import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/tokens.dart';
import '../shared/widgets/app_tab_bar.dart';
import 'routes.dart';

/// Holds the three tabs so the bar survives a tab change.
///
/// The bar is passed to the scaffold rather than composed into each page,
/// because where it sits is a platform decision and no page should know about
/// it.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  AppTab get _current => switch (location) {
        Routes.chats => AppTab.chats,
        Routes.account => AppTab.you,
        _ => AppTab.home,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.group,
      // iOS floats the bar over the content, so the body extends underneath it.
      // Android docks it, so it does not.
      extendBody: true,
      body: child,
      bottomNavigationBar: AppTabBar(
        current: _current,
        chatsBadge: 2,
        onSelect: (tab) => switch (tab) {
          AppTab.home => context.go(Routes.home),
          AppTab.chats => context.go(Routes.chats),
          AppTab.you => context.go(Routes.account),
        },
      ),
    );
  }
}
