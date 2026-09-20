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

/// Several answers to one question, kept open until Done.
///
/// The design draws this as a pushed screen with its own Back and Done. It is a
/// sheet here because every other one-question step in this form is one, and a
/// form that pushes for one answer and slides up for the next reads as two
/// different apps.
///
/// Options are (key, label) in the order they should appear, which is the order
/// the server sent. Returns the chosen keys, or null if they backed out.
Future<Set<String>?> showMultiChoiceSheet(
  BuildContext context, {
  required String title,
  required List<(String, String)> options,
  required Set<String> initial,
  String? subtitle,
  String saveLabel = 'Done',
}) {
  return showAppSheet<Set<String>>(
    context,
    builder: (sheetContext) => _MultiChoice(
      title: title,
      subtitle: subtitle,
      options: options,
      initial: initial,
      saveLabel: saveLabel,
    ),
  );
}

class _MultiChoice extends StatefulWidget {
  const _MultiChoice({
    required this.title,
    required this.options,
    required this.initial,
    required this.saveLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<(String, String)> options;
  final Set<String> initial;
  final String saveLabel;

  @override
  State<_MultiChoice> createState() => _MultiChoiceState();
}

class _MultiChoiceState extends State<_MultiChoice> {
  late final Set<String> _chosen = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: AppText.title3),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(widget.subtitle!, style: AppText.caption),
        ],
        const SizedBox(height: 12),
        // Half the screen at most: twelve languages do not fit, and a sheet
        // that grows past the top edge cannot be dismissed.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (key, label) in widget.options)
                Pressable(
                  onTap: () => setState(
                    () => _chosen.contains(key)
                        ? _chosen.remove(key)
                        : _chosen.add(key),
                  ),
                  child: Container(
                    height: 46,
                    alignment: Alignment.centerLeft,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.separator,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(label, style: AppText.body)),
                        if (_chosen.contains(key))
                          const Icon(
                            Icons.check,
                            size: 18,
                            color: AppColors.accent,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Pressable(
          // Choosing nothing is a real answer here: it means not stated.
          onTap: () => Navigator.of(context).pop(_chosen),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(Radii.row),
            ),
            child: Text(
              widget.saveLabel,
              style: AppText.button.copyWith(color: AppColors.onAccent),
            ),
          ),
        ),
      ],
    );
  }
}

/// One field, asked for on its own.
///
/// Used for a first name and for a written prompt answer. It is a sheet rather
/// than a screen because it is one question, and it keeps the keyboard and the
/// Save button in the same place both times.
///
/// Returns the trimmed text, or null if they backed out.
Future<String?> showTextEntrySheet(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  int maxLength = 200,
  int minLines = 1,
  String saveLabel = 'Save',
}) {
  return showAppSheet<String>(
    context,
    builder: (sheetContext) => _TextEntry(
      title: title,
      hint: hint,
      initial: initial,
      maxLength: maxLength,
      minLines: minLines,
      saveLabel: saveLabel,
    ),
  );
}

class _TextEntry extends StatefulWidget {
  const _TextEntry({
    required this.title,
    required this.hint,
    required this.initial,
    required this.maxLength,
    required this.minLines,
    required this.saveLabel,
  });

  final String title;
  final String hint;
  final String initial;
  final int maxLength;
  final int minLines;
  final String saveLabel;

  @override
  State<_TextEntry> createState() => _TextEntryState();
}

class _TextEntryState extends State<_TextEntry> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final left = widget.maxLength - _controller.text.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: AppText.title3),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            // Bounded here as well as on the server, so a paste cannot push an
            // unbounded payload at the API.
            maxLength: widget.maxLength,
            minLines: widget.minLines,
            maxLines: widget.minLines == 1 ? 1 : widget.minLines + 3,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.body,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppText.body.copyWith(color: AppColors.label4),
              counterText: left < 40 ? '$left left' : '',
              counterStyle: AppText.micro,
              filled: true,
              fillColor: AppColors.canvas,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Pressable(
            onTap: text.isEmpty
                ? null
                : () => Navigator.of(context).pop(text),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: text.isEmpty ? AppColors.fill2 : AppColors.fill,
                borderRadius: BorderRadius.circular(Radii.row),
              ),
              child: Text(
                widget.saveLabel,
                style: AppText.button.copyWith(
                  color: text.isEmpty ? AppColors.label3 : AppColors.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The last step before an account is erased.
///
/// Deleting is immediate and final: no grace period, no undo, and deliberately
/// no code by SMS. That makes an unlocked, signed-in phone enough to erase the
/// account, so the one thing standing in the way is having to type the word.
/// Returns what was typed, or null if they backed out.
Future<String?> showDeleteConfirmation(BuildContext context) {
  return showAppSheet<String>(
    context,
    builder: (sheetContext) => _DeleteConfirmation(),
  );
}

class _DeleteConfirmation extends StatefulWidget {
  @override
  State<_DeleteConfirmation> createState() => _DeleteConfirmationState();
}

class _DeleteConfirmationState extends State<_DeleteConfirmation> {
  static const _word = 'delete';

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.text.trim().toLowerCase() == _word;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This cannot be undone', style: AppText.title3),
          const SizedBox(height: 8),
          Text(
            'Your profile, your tiles, your photos and every conversation are '
            'erased straight away. Type $_word to confirm.',
            style: AppText.callout,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            style: AppText.body,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _word,
              hintStyle: AppText.body.copyWith(color: AppColors.label4),
              filled: true,
              fillColor: AppColors.canvas,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: const BorderSide(color: AppColors.destructive),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Pressable(
            onTap: ready
                ? () => Navigator.of(context).pop(_controller.text.trim())
                : null,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ready ? AppColors.destructive : AppColors.fill2,
                borderRadius: BorderRadius.circular(Radii.row),
              ),
              child: Text(
                'Delete my account',
                style: AppText.button.copyWith(
                  color: ready ? AppColors.label : AppColors.label3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Pressable(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              height: 46,
              child: Center(
                child: Text(
                  'Keep my account',
                  style: AppText.button.copyWith(color: AppColors.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
