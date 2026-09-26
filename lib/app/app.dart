import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push/push.dart';
import '../core/session/session.dart';
import '../core/theme/app_theme.dart';
import 'in_app_banner.dart';
import 'router.dart';
import 'routes.dart';

class EjiojiApp extends ConsumerStatefulWidget {
  const EjiojiApp({super.key});

  @override
  ConsumerState<EjiojiApp> createState() => _EjiojiAppState();
}

class _EjiojiAppState extends ConsumerState<EjiojiApp> {
  StreamSubscription<PushOpen>? _taps;

  /// Read once: `Push.arrivals` is a new stream on every read.
  final Stream<PushShown> _arrivals = Push.arrivals;

  @override
  void initState() {
    super.initState();
    // Two ways in: the app was opened by a notification, or it was already
    // running behind one. Both land on the same screen.
    _taps = Push.taps.listen(_open);
    unawaited(
      Push.launchedBy().then((open) {
        if (open != null) _open(open);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    super.dispose();
  }

  /// Opens what the notification was about.
  ///
  /// Nothing is trusted from the payload beyond an id: a request opens the
  /// list it is waiting in rather than acting on it, and a message opens the
  /// conversation, which loads from the server like any other.
  void _open(PushOpen open) {
    if (!ref.read(sessionProvider).isSignedIn) return;
    final router = ref.read(routerProvider);
    final id = open.id;
    switch (open.kind) {
      case PushKind.message:
      case PushKind.match:
        if (id != null) router.push(Routes.conversationWith(id));
      case PushKind.request:
        router.go(Routes.chats);
      case PushKind.profileViews:
        router.push(Routes.profileViews);
    }
  }

  /// Whether a push that arrived while the app was open gets a banner. Not
  /// one about the conversation already on screen, which shows the message
  /// itself, and nothing at all while signed out.
  bool _shouldShow(PushShown shown) {
    if (!ref.read(sessionProvider).isSignedIn) return false;
    final open = shown.open;
    return switch (open.kind) {
      PushKind.message || PushKind.match =>
        open.id == null || open.id != OpenConversations.top,
      PushKind.request || PushKind.profileViews => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: MaterialApp.router(
        title: 'theonebytwo',
        debugShowCheckedModeBanner: false,
        routerConfig: ref.watch(routerProvider),
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        // Dark only. The system setting is deliberately ignored rather than
        // followed — this product has one look, and a half-built light mode is
        // worse than none.
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          // Text scaling is honoured up to a point. Past 1.3 the tiles — which
          // are a number and a caption in a fixed box — stop being readable at
          // all, so the cap protects the content rather than the layout.
          final scale = MediaQuery.textScalerOf(context).clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.3,
          );
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scale),
            child: InAppBanner(
              arrivals: _arrivals,
              shouldShow: _shouldShow,
              onTap: _open,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
