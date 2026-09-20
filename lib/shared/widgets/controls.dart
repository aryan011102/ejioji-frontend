import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'pressable.dart';

/// UISwitch, brand-tinted rather than system green.
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 51,
          height: 31,
          decoration: BoxDecoration(
            color: value ? AppColors.fill : AppColors.track,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Ease.emphasised,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 27,
              height: 27,
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3D000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two or three mutually exclusive options. Three states is a segmented
/// control's job; two is usually a switch's.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.fill2,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final (key, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: Motion.press,
                  height: 29,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: key == value
                        ? AppColors.row
                        : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    label,
                    style: AppText.footnote.copyWith(
                      fontSize: 13.5,
                      color: key == value
                          ? AppColors.label
                          : AppColors.label2,
                      fontWeight:
                          key == value ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A filter chip, and the tab-style chip with a count on it.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.fill : AppColors.row,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0x00000000) : AppColors.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The tick is what reads as "chosen" at a glance; the fill alone
            // does not, once several chips sit in one wrap.
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: AppColors.onAccent),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.body.copyWith(
                fontSize: 14.5,
                color: selected ? AppColors.onAccent : AppColors.label,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill that reads as a fact rather than a control — the profile pills.
class FactPill extends StatelessWidget {
  const FactPill({required this.icon, required this.label, super.key});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: AppColors.row,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: AppText.body.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}

/// One continuous fill, never a row of dashes.
///
/// Dashes say "N separate tasks"; a bar says "one task, this far through",
/// which is what picking insights across categories actually is.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    this.muted = false,
    super.key,
  });

  /// 0..1
  final double value;

  /// At the cap the bar goes grey rather than red — full is a state, not an
  /// error.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 5,
        child: Stack(
          children: [
            const ColoredBox(
              color: AppColors.fill2,
              child: SizedBox.expand(),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Ease.emphasised,
                color: muted ? AppColors.label3 : AppColors.fill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A two-thumb range, for the one filter that is a range rather than a set.
///
/// Age is a pair of dropdowns in most apps, which makes picking 24–32 a
/// four-tap job. This is one drag.
class AgeRangeSlider extends StatelessWidget {
  const AgeRangeSlider({
    required this.value,
    required this.onChanged,
    this.min = 18,
    this.max = 60,
    super.key,
  });

  final RangeValues value;
  final ValueChanged<RangeValues> onChanged;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: const SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.fill,
        inactiveTrackColor: AppColors.track,
        rangeThumbShape: RoundRangeSliderThumbShape(
          enabledThumbRadius: 14,
          elevation: 3,
        ),
        thumbColor: Color(0xFFFFFFFF),
        overlayColor: Color(0x229B4487),
        rangeTrackShape: RectangularRangeSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: RangeSlider(
        values: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}
