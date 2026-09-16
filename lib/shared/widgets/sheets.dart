import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'pressable.dart';

/// One action in a sheet.
class SheetAction {
  const SheetAction(
    this.label, {
    this.onTap,
    this.destructive = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final IconData? icon;
}

/// The iOS action sheet, rebuilt rather than borrowed.
///
/// Cupertino's own sheet cannot be tinted to the plum system without fighting
/// it, and this app uses one enough times that owning it is cheaper.
///
/// Returns the index of the action taken, or null if it was dismissed —
/// callers must handle null, because the scrim and Cancel are both real
/// answers.
Future<int?> showAppActionSheet(
  BuildContext context, {
  String? title,
  String? message,
  required List<SheetAction> actions,
  String cancelLabel = 'Cancel',
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: const Color(0x00000000),
    barrierColor: AppColors.scrim,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.menu,
                borderRadius: BorderRadius.circular(Radii.sheet),
                border: Border.all(color: AppColors.hairline),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sheet),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null || message != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
                        child: Column(
                          children: [
                            if (title != null)
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: AppText.footnote.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.label2,
                                ),
                              ),
                            if (message != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: AppText.caption.copyWith(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: AppColors.separator,
                      ),
                    ],
                    for (var i = 0; i < actions.length; i++) ...[
                      PressableRow(
                        onTap: () {
                          Navigator.of(context).pop(i);
                          actions[i].onTap?.call();
                        },
                        child: SizedBox(
                          height: 57,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                actions[i].label,
                                style: AppText.navAction.copyWith(
                                  fontSize: 20,
                                  color: actions[i].destructive
                                      ? AppColors.destructive
                                      : AppColors.accent,
                                ),
                              ),
                              if (actions[i].icon != null) ...[
                                const SizedBox(width: 10),
                                Icon(
                                  actions[i].icon,
                                  size: 20,
                                  color: actions[i].destructive
                                      ? AppColors.destructive
                                      : AppColors.accent,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (i < actions.length - 1)
                        const Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: AppColors.separator,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Pressable(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                height: 57,
                decoration: BoxDecoration(
                  color: AppColors.row,
                  borderRadius: BorderRadius.circular(Radii.sheet),
                ),
                alignment: Alignment.center,
                child: Text(
                  cancelLabel,
                  style: AppText.navAction.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A sheet with arbitrary content — the friends-and-family handshake is the
/// only one, and it needs two switches rather than a list of actions.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: const Color(0x00000000),
    barrierColor: AppColors.scrim,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.row,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: builder(context),
          ),
        ),
      ),
    ),
  );
}

/// The quiet confirmation. Addressed to whoever pressed, and never posted
/// anywhere another person can see it.
void showAppToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1A1116),
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(26, 0, 26, 120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.row),
        side: const BorderSide(color: AppColors.glassEdge),
      ),
      duration: const Duration(milliseconds: 3200),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: AppText.footnote.copyWith(color: AppColors.label),
      ),
    ),
  );
}
