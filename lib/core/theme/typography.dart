import 'package:flutter/widgets.dart';

import 'platform.dart';
import 'tokens.dart';

/// Type.
///
/// One scale, two typefaces. iOS gets the system face, which is SF Pro and
/// which Flutter reaches by passing null. Android asks for Google Sans by name
/// and falls back to Roboto when it is not installed — that fallback is the
/// expected case on a stock device, not a failure.
///
/// Sizes and letter-spacing are lifted from the mocks unchanged. Large numbers
/// are tight (-1.1) because the tiles are set in them; body copy is barely
/// tracked at all.
abstract final class AppText {
  static String? get _family => AppPlatform.isAndroid ? 'Google Sans' : null;

  static const List<String> _fallback = <String>[
    'Google Sans',
    'Roboto',
    'SF Pro Text',
  ];

  static TextStyle _s({
    required double size,
    required double height,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    Color color = AppColors.label,
  }) =>
      TextStyle(
        fontFamily: _family,
        fontFamilyFallback: AppPlatform.isAndroid ? _fallback : null,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: spacing,
        color: color,
      );

  // Titles.
  static TextStyle get largeTitle =>
      _s(size: 34, height: 41, weight: FontWeight.w700, spacing: -1);
  static TextStyle get title1 =>
      _s(size: 28, height: 34, weight: FontWeight.w700, spacing: -0.9);
  static TextStyle get title2 =>
      _s(size: 25, height: 31, weight: FontWeight.w700, spacing: -0.7);
  static TextStyle get title3 =>
      _s(size: 19, height: 24, weight: FontWeight.w600, spacing: -0.4);

  // Body.
  static TextStyle get body => _s(size: 16, height: 21, spacing: -0.2);
  static TextStyle get bodyStrong =>
      _s(size: 16, height: 21, weight: FontWeight.w600, spacing: -0.2);
  static TextStyle get callout =>
      _s(size: 15, height: 21, color: AppColors.label2);
  static TextStyle get footnote =>
      _s(size: 13, height: 18, color: AppColors.label2);
  static TextStyle get caption =>
      _s(size: 12, height: 16.5, color: AppColors.label3);
  static TextStyle get micro =>
      _s(size: 11.5, height: 16, color: AppColors.label4);

  // Controls.
  static TextStyle get button =>
      _s(size: 17, height: 22, weight: FontWeight.w600, spacing: -0.2);
  static TextStyle get navAction => _s(size: 17, height: 22, spacing: -0.2);
  static TextStyle get navTitle =>
      _s(size: 17, height: 22, weight: FontWeight.w600, spacing: -0.3);
  static TextStyle get tabLabel => _s(size: 10, height: 13);

  /// The caps label above a settings group.
  static TextStyle get groupHeader => _s(
        size: 12.5,
        height: 17,
        weight: FontWeight.w600,
        spacing: 0.3,
        color: AppColors.label3,
      );

  /// The number on a tile. Long values shrink rather than wrap, because a
  /// wrapped number stops reading as one.
  static TextStyle tileNumber(double size) => _s(
        size: size,
        height: size * 1.02,
        weight: FontWeight.w700,
        spacing: -1.1,
      );

  static TextStyle get tileCaption => _s(
        size: 12.5,
        height: 16.5,
        weight: FontWeight.w500,
        color: const Color(0xE0FFFFFF),
      );
}
