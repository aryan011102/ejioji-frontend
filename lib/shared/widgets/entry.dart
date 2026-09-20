import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'pressable.dart';

/// The number pad on the sign-in screens.
///
/// Custom rather than the system keyboard because these two screens accept
/// digits and nothing else — no paste of a wrong-format number, no emoji
/// keyboard, no autocorrect, and no third-party keyboard in the path of a
/// phone number.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    required this.onDigit,
    required this.onDelete,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  /// Digit, then the letters under it. The letters are what make this read
  /// as the phone keypad rather than as five rows of buttons.
  static const _keys = [
    ('1', ''), ('2', 'ABC'), ('3', 'DEF'), //
    ('4', 'GHI'), ('5', 'JKL'), ('6', 'MNO'), //
    ('7', 'PQRS'), ('8', 'TUV'), ('9', 'WXYZ'), //
    ('', ''), ('0', '+'), ('del', ''), //
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      // The screen's own colour, not a plate of its own: the keypad is the
      // bottom of this screen, not a keyboard that slid up over it.
      color: AppColors.group,
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        6 + MediaQuery.paddingOf(context).bottom,
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 7,
        crossAxisSpacing: 8,
        childAspectRatio: 2.65,
        children: [
          for (final (key, letters) in _keys)
            if (key.isEmpty)
              const SizedBox.shrink()
            else
              Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  key == 'del' ? onDelete() : onDigit(key);
                },
                semanticLabel: key == 'del' ? 'Delete' : key,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: key == 'del' ? null : AppColors.row,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: key == 'del'
                        ? const Icon(
                            Icons.backspace_outlined,
                            size: 22,
                            color: AppColors.label,
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                key,
                                style: AppText.title1.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0,
                                  height: 1.1,
                                ),
                              ),
                              if (letters.isNotEmpty)
                                Text(
                                  letters,
                                  style: AppText.caption.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.4,
                                    color: AppColors.label,
                                    height: 1.1,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Six boxes, one per digit, with the next one outlined.
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({required this.code, this.length = 6, super.key});

  final String code;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verification code, ${code.length} of $length digits entered',
      child: Row(
        children: [
          for (var i = 0; i < length; i++) ...[
            if (i > 0) const SizedBox(width: 9),
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.row,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: i == code.length
                        ? AppColors.accent
                        : AppColors.hairline,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  i < code.length ? code[i] : '',
                  style: AppText.title1.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable field that reads like a filled-in answer.
///
/// The label sits left and the answer right, because a completed form is
/// scanned for its answers — the questions are settled.
class FieldRow extends StatelessWidget {
  const FieldRow({
    required this.label,
    this.value,
    this.placeholder,
    this.onTap,
    this.last = false,
    super.key,
  });

  final String label;
  final String? value;
  final String? placeholder;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return Column(
      children: [
        PressableRow(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(label, style: AppText.body),
                  ),
                  Expanded(
                    child: Text(
                      filled ? value! : (placeholder ?? ''),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        color: filled ? AppColors.label2 : AppColors.label4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.label4,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: AppColors.separator,
            ),
          ),
      ],
    );
  }
}
