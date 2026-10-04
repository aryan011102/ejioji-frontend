import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../models/tile.dart';
import 'pressable.dart';
import 'quoted_tile.dart';
import 'sheets.dart';

/// The most a line sent with a request can be. The server holds the same
/// number; this only stops the field from taking more.
const requestNoteMaxChars = 150;

/// "Chat about this": the tile being asked about, a line, and Send.
///
/// Only ever with a tile (Aryan's call, 2026-09-27), so everything written
/// before a match is about something on the other person's profile. Contact
/// details are refused by the server, because they have not said yes yet.
///
/// **A line is required**: Send does nothing until something is written, so a
/// tile can never arrive on its own with nothing said about it. The server
/// still takes a request with no line, so this is the app's rule, not its.
///
/// [send] makes the request with what was written, returns what to tell the
/// person, and throws [ApiException] if it is refused. The sheet says it,
/// because the screen behind may be gone by then: on Home, asking moves the
/// deck on. The sheet stays open on a refusal and shows the server's message
/// under the field, so the words that caused it are still there to change.
/// Returns true once it has gone through, null if they backed out.
Future<bool?> showAskAboutSheet(
  BuildContext context, {
  required String name,
  required ProfileTile tile,
  required Future<String> Function(String note) send,
}) {
  return showAppSheet<bool>(
    context,
    builder: (_) => _AskAbout(name: name, tile: tile, send: send),
  );
}

class _AskAbout extends StatefulWidget {
  const _AskAbout({required this.name, required this.tile, required this.send});

  final String name;
  final ProfileTile tile;
  final Future<String> Function(String note) send;

  @override
  State<_AskAbout> createState() => _AskAboutState();
}

class _AskAboutState extends State<_AskAbout> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _refusal;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _controller.text.trim();
    // Nothing written is not a request. The button is already dimmed, so this
    // only catches the keyboard's send key.
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
      _refusal = null;
    });
    try {
      final said = await widget.send(text);
      if (!mounted) return;
      showAppToast(context, said);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // A refused line keeps the sheet open on it. Anything else (the daily
      // allowance, someone no longer there) is not about the words, so the
      // sheet closes and says so.
      if (e.code == 'text_rejected') {
        setState(() => _refusal = e.message);
      } else {
        Navigator.of(context).pop();
        showAppToast(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = requestNoteMaxChars - _controller.text.length;
    final refusal = _refusal;
    // Spaces alone are nothing written, and the field rebuilds on every
    // keystroke, so the button follows what is actually there.
    final empty = _controller.text.trim().isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ask ${widget.name} about this', style: AppText.title3),
          const SizedBox(height: 12),
          QuotedTile(tile: TileQuote.preview(widget.tile)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: requestNoteMaxChars,
            maxLines: 1,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: AppText.body,
            onChanged: (_) => setState(() => _refusal = null),
            decoration: InputDecoration(
              hintText: 'Add a line',
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
                borderSide: BorderSide(
                  color: refusal == null
                      ? AppColors.hairline
                      : AppColors.destructive,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: BorderSide(
                  color: refusal == null
                      ? AppColors.accent
                      : AppColors.destructive,
                ),
              ),
            ),
          ),
          // Only ever a refusal here. Nothing stands under the field by
          // default: the sheet already says whose tile this is, and the line
          // about numbers and handles was in the way (Aryan's call).
          if (refusal != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Text(
                refusal,
                style: AppText.footnote.copyWith(color: AppColors.destructive),
              ),
            )
          else
            const SizedBox(height: 12),
          Pressable(
            onTap: _sending || empty ? null : _send,
            semanticLabel: 'Send request to ${widget.name}',
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _sending || empty ? AppColors.fill2 : AppColors.fill,
                borderRadius: BorderRadius.circular(Radii.row),
              ),
              child: Text(
                _sending ? 'Sending…' : 'Send request',
                style: AppText.button.copyWith(
                  color: _sending || empty
                      ? AppColors.label3
                      : AppColors.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
