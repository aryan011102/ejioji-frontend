import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/tokens.dart';
import '../data/live_events.dart';
import '../data/providers.dart';
import '../shared/widgets/app_tab_bar.dart';
import 'routes.dart';

/// Holds the three tabs so the bar survives a tab change.
///
/// The bar is passed to the scaffold rather than composed into each page,
/// because where it sits is a platform decision and no page should know about
/// it.
///
/// The shell also holds the chat socket open for as long as someone is inside
/// the app, and turns its events into refetches: a new message, request or
/// match makes the lists (and the badge) read the server again. The socket
/// only says that something changed; the lists always come from the API.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<LiveEvent>? _events;

  AppTab get _current => switch (widget.location) {
        Routes.chats => AppTab.chats,
        Routes.account => AppTab.you,
        _ => AppTab.home,
      };

  @override
  void initState() {
    super.initState();
    _events = ref.read(liveEventsProvider).events.listen(_onEvent);
  }

  void _onEvent(LiveEvent event) {
    switch (event.type) {
      case 'message.new' || 'messages.read' || 'conversation.ended':
        ref.invalidate(conversationsProvider);
      case 'request.new':
        ref.invalidate(incomingRequestsProvider);
      case 'match.new':
        ref
          ..invalidate(conversationsProvider)
          ..invalidate(outgoingRequestsProvider)
          ..invalidate(incomingRequestsProvider);
      case LiveEvent.resync:
        ref
          ..invalidate(conversationsProvider)
          ..invalidate(incomingRequestsProvider)
          ..invalidate(outgoingRequestsProvider);
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the socket stays open while the shell is on screen.
    ref.watch(liveEventsProvider);

    final unread = ref.watch(conversationsProvider).valueOrNull?.fold<int>(
              0,
              (total, c) => total + c.unread,
            ) ??
        0;
    final waiting = ref.watch(incomingRequestsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.group,
      // iOS floats the bar over the content, so the body extends underneath it.
      // Android docks it, so it does not.
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: AppTabBar(
        current: _current,
        chatsBadge: unread + waiting,
        onSelect: (tab) => switch (tab) {
          AppTab.home => context.go(Routes.home),
          AppTab.chats => context.go(Routes.chats),
          AppTab.you => context.go(Routes.account),
        },
      ),
    );
  }
}
