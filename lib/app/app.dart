import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class EjiojiApp extends ConsumerWidget {
  const EjiojiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
