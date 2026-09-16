import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/pressable.dart';
import '../../profile/presentation/profile_page.dart';

/// Home is the viewer's view.
///
/// The screen a stranger's profile is shown on is the screen the app opens on,
/// so it carries the app's chrome as well as the profile's — and the profile
/// underneath is the same component, not a copy of it.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const ProfilePage(mode: ProfileMode.viewer),
        // Home's own bar floats over the profile rather than pushing it down,
        // so the wall reaches the top of the screen.
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.paddingOf(context).top,
          child: const _HomeBar(),
        ),
      ],
    );
  }
}

class _HomeBar extends StatelessWidget {
  const _HomeBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: Insets.md),
          Pressable(
            onTap: () => context.push(Routes.filters),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filters',
                    style: AppText.navAction.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Pressable(
            onTap: () => context.push(Routes.notifications),
            semanticLabel: 'Notifications',
            child: const Padding(
              padding: EdgeInsets.fromLTRB(6, 6, 14, 2),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 22,
                    color: AppColors.accent,
                  ),
                  Positioned(
                    top: 1,
                    right: 1,
                    child: SizedBox(
                      width: 9,
                      height: 9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.destructive,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
