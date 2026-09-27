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

/// "Chat about this", with an optional line: the tile being asked about, a
/// field, and Send.
///
/// Only ever with a tile (Aryan's call, 2026-09-27), so everything written
/// before a match is about something on the other person's profile. Contact
/// details are refused by the server, because they have not said yes yet.
///
/// [send] makes the request with whatever was written (null for nothing),
/// returns what to tell the person, and throws [ApiException] if it is
/// refused. The sheet says it, because the screen behind may be gone by then:
/// on Home, asking moves the deck on. The sheet stays open on a refusal
/// and shows the server's message under the field, so the words that caused it
/// are still there to change. Returns true once it has gone through, null if
/// they backed out.
Future<bool?> showAskAboutSheet(
  BuildContext context, {
  required String name,
  required ProfileTile tile,
  required Future<String> Function(String? note) send,
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
  final Future<String> Function(String? note) send;

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
    setState(() {
      _sending = true;
      _refusal = null;
    });
    try {
      final said = await widget.send(text.isEmpty ? null : text);
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
              hintText: 'Add a line (optional)',
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
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(
              refusal ??
                  '${widget.name} sees this with your request. Numbers and '
                      'handles can wait until they say yes.',
              style: AppText.footnote.copyWith(
                color: refusal == null
                    ? AppColors.label3
                    : AppColors.destructive,
              ),
            ),
          ),
          Pressable(
            onTap: _sending ? null : _send,
            semanticLabel: 'Send request to ${widget.name}',
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _sending ? AppColors.fill2 : AppColors.fill,
                borderRadius: BorderRadius.circular(Radii.row),
              ),
              child: Text(
                _sending ? 'Sending…' : 'Send request',
                style: AppText.button.copyWith(
                  color: _sending ? AppColors.label3 : AppColors.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
