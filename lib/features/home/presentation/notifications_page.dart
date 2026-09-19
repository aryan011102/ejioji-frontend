import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/not_yet.dart';

/// A list of what happened while you were away.
///
/// The backend has no such list yet: new messages, requests and matches reach
/// the app as they happen (the chat socket, and pushes once Firebase is set
/// up), but nothing records them for a screen like this. So it says so rather
/// than showing invented rows. The design this replaced also announced
/// "Spotify has something new", which could never be true: every source is
/// read once, and nothing is fetched in the background.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Notifications',
        backLabel: 'Home',
        onBack: () => context.pop(),
      ),
      child: const NotYet(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications are coming soon.',
        body: 'New messages and chat requests already show up in Chats as '
            'they happen.',
      ),
    );
  }
}
