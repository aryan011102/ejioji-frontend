import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// The Material theme exists only so framework widgets that reach for it — the
/// text selection handles, the scrollbar, the ripple — land in the right place.
/// Screens are built from the widgets in `shared/widgets`, not from Material
/// components, so this file stays small on purpose.
abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.fill,
      onSecondary: AppColors.onAccent,
      surface: AppColors.row,
      onSurface: AppColors.label,
      error: AppColors.destructive,
      onError: AppColors.onAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.group,
      canvasColor: AppColors.group,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x669B4487),
        selectionHandleColor: AppColors.accent,
      ),
      textTheme: TextTheme(
        headlineLarge: AppText.largeTitle,
        headlineMedium: AppText.title1,
        titleLarge: AppText.title3,
        bodyLarge: AppText.body,
        bodyMedium: AppText.callout,
        labelLarge: AppText.button,
      ),
      // The app is dark-only, so the status bar is always light-on-dark and
      // the Android nav bar is painted to match the screen rather than left
      // as a black strip under a black screen with a visible seam.
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.group,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
    );
  }

  /// Applied once at boot. Dark-only means we can set this and never think
  /// about it again.
  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.group,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}
