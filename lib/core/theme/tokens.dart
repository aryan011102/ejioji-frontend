import 'package:flutter/widgets.dart';

/// The plum system, dark only.
///
/// Every colour in the app comes from here. Nothing anywhere else may write a
/// hex value: if a screen needs a colour that is not in this file, the answer
/// is to add it here and say what it is for, not to inline it.
///
/// The names match the mocks one to one (`--label-2` is [label2]) so a design
/// change can be traced from a comp to a constant without a translation step.
abstract final class AppColors {
  // Surfaces, back to front.
  static const canvas = Color(0xFF0D0D0F); // behind everything
  static const group = Color(0xFF000000); // the screen itself
  static const row = Color(0xFF1C1C1E); // cards, rows, sheets
  static const menu = Color(0xFF252527); // action sheet plate

  // Type, in the four weights the system uses.
  static const label = Color(0xFFFFFFFF);
  static const label2 = Color(0x9EEBEBF5); // .62
  static const label3 = Color(0x66EBEBF5); // .40
  static const label4 = Color(0x3DEBEBF5); // .24

  // Lines and fills.
  static const separator = Color(0x29EBEBF5); // .16
  static const hairline = Color(0x1AFFFFFF); // .10
  static const fill2 = Color(0x33787880); // .20
  static const fill3 = Color(0x52787880); // .32
  static const track = Color(0x52787880);

  // Brand. `accent` is what type and icons use; `fill` is what a solid control
  // is painted with. They differ on purpose — pink reads on black, plum does
  // not, and plum holds white type where pink would not.
  static const accent = Color(0xFFEF798A);
  static const fill = Color(0xFF9B4487);
  static const onAccent = Color(0xFFFFFFFF);
  static const glow = Color(0x619B4487);
  static const pink = Color(0xFFEF798A);

  // Status. Blue and gold are ticks, not brand: a badge people are asked to
  // trust should look the way badges look everywhere else on a phone.
  static const ok = Color(0xFF30D158);
  static const destructive = Color(0xFFFF453A);
  static const blue = Color(0xFF4DA3FF);
  static const blueSoft = Color(0x294DA3FF);
  static const gold = Color(0xFFE3B341);
  static const goldSoft = Color(0x29E3B341);
  static const warnSoft = Color(0x24FF453A);

  // Chrome.
  static const glass = Color(0xC21C1C1E); // .76
  static const glassEdge = Color(0x24FFFFFF); // .14
  static const scrim = Color(0x80000000);
  static const tileEdge = Color(0x24FFFFFF);
  static const bubbleThem = Color(0xFF1C1C1E);
  static const bubbleThemEdge = Color(0x1AFFFFFF);
  static const photoEmpty = Color(0xFF1C1C1E);
  static const photoEdge = Color(0x59EF798A);

  /// The promo surface — the only place plum is a background rather than an
  /// accent.
  static const promo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5A2450), Color(0xFF1A0A16)],
    stops: [0.0, 0.82],
  );
}

/// The twelve tile gradients, at their dark values.
///
/// Plum is deliberately absent: it is chrome, and a wall of tiles in the brand
/// colour reads as one thing rather than twelve.
abstract final class TileTones {
  static final saffron = _t(const Color(0xFFC9812B), const Color(0xFF7A3A04));
  static final chilli = _t(const Color(0xFFD14A34), const Color(0xFF851C15));
  static final cocoa = _t(const Color(0xFF7A5340), const Color(0xFF2C1A12));
  static final olive = _t(const Color(0xFF7C8B41), const Color(0xFF2A3212));
  static final berry = _t(const Color(0xFFA8508F), const Color(0xFF4E1F42));
  static final night = _t(const Color(0xFF33395C), const Color(0xFF12172A));
  static final indigo = _t(const Color(0xFF5B49A8), const Color(0xFF241A4C));
  static final cobalt = _t(const Color(0xFF2E71B4), const Color(0xFF0D3760));
  static final teal = _t(const Color(0xFF2C8479), const Color(0xFF0B3F3A));
  static final moss = _t(const Color(0xFF4A8248), const Color(0xFF12331A));
  static final rose = _t(const Color(0xFFC24E66), const Color(0xFF6E162C));
  static final slate = _t(const Color(0xFF5F6874), const Color(0xFF2A2F36));

  static final byName = <String, LinearGradient>{
    'saffron': saffron,
    'chilli': chilli,
    'cocoa': cocoa,
    'olive': olive,
    'berry': berry,
    'night': night,
    'indigo': indigo,
    'cobalt': cobalt,
    'teal': teal,
    'moss': moss,
    'rose': rose,
    'slate': slate,
  };

  /// Falls back to slate rather than throwing: a tile with an unknown tone is
  /// a content problem, and a blank screen is a worse answer than a grey tile.
  static LinearGradient of(String? name) => byName[name] ?? slate;

  static LinearGradient _t(Color a, Color b) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [a, b],
        transform: const GradientRotation(2.65),
      );
}

/// Scrims. Light tile fills stay bright and the type on them stays legible,
/// which two different gradients cannot both do without help.
abstract final class Scrims {
  static const flat = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x47000000)],
    stops: [0.42, 1.0],
  );

  static const media = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xB3000000)],
    stops: [0.26, 1.0],
  );
}

/// Spacing and radii, named after what they are rather than their value.
abstract final class Insets {
  /// The gutter every screen honours.
  static const gutter = 16.0;

  /// The gutter a large title sits on — four further in, so a 34pt title
  /// optically aligns with 16pt body text beneath it.
  static const titleGutter = 20.0;

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const row = 14.0;
  static const card = 16.0;
  static const tile = 20.0;
  static const control = 26.0;
  static const chip = 16.0;
  static const sheet = 14.0;
}

abstract final class Motion {
  static const press = Duration(milliseconds: 120);
  static const sheet = Duration(milliseconds: 280);
  static const fade = Duration(milliseconds: 220);
  static const page = Duration(milliseconds: 260);
}

abstract final class Ease {
  /// The one easing curve this app uses for anything that moves a distance.
  static const emphasised = Cubic(0.22, 1, 0.36, 1);
}
