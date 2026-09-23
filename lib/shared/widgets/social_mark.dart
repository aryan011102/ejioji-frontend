import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../models/social.dart';

/// A network's square, in its own colours, at any size. The connect screen and
/// settings draw it at 30; a chip under a name draws it at 16.
class SocialMark extends StatelessWidget {
  const SocialMark(this.network, {this.size = 30, super.key});

  final SocialNetwork network;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = size * 0.6;
    final (Decoration back, Widget mark) = switch (network) {
      SocialNetwork.instagram => (
          BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                BrandColors.instagramFrom,
                BrandColors.instagramVia,
                BrandColors.instagramTo,
              ],
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            border: Border.all(color: BrandColors.edge),
          ),
          Icon(Icons.camera_alt_outlined, size: glyph, color: AppColors.label),
        ),
      SocialNetwork.x => (
          _plain(BrandColors.x),
          Text(
            'X',
            style: AppText.title3.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: glyph,
              height: 1,
            ),
          ),
        ),
      SocialNetwork.linkedin => (
          _plain(BrandColors.linkedin),
          Text(
            'in',
            style: AppText.title3.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: glyph * 0.95,
              height: 1,
            ),
          ),
        ),
      SocialNetwork.unknown => (
          _plain(AppColors.fill2),
          Icon(Icons.link, size: glyph, color: AppColors.label2),
        ),
    };
    return Container(
      width: size,
      height: size,
      decoration: back,
      alignment: Alignment.center,
      child: mark,
    );
  }

  BoxDecoration _plain(Color color) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: BrandColors.edge),
      );
}
