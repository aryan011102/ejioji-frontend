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
/// **Sending the line needs a verified profile** (2026-10-05). The recipient
/// reads it as the conversation's first line, so it is held to the same rule as
/// a chat message. Unverified, the sheet still opens and still takes what they
/// write; the button says so and goes to verification instead of sending. The
/// server refuses it too (403 `verification_required`), so this is the app
/// saying what the rule is, not the rule itself. A knock with no words is not
/// gated, which is why the plain "Chat with" button is untouched.
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
  bool verified = true,
  bool replying = false,
  VoidCallback? onVerify,
}) {
  return showAppSheet<bool>(
    context,
    builder: (_) => _AskAbout(
      name: name,
      tile: tile,
      send: send,
      verified: verified,
      replying: replying,
      onVerify: onVerify,
    ),
  );
}

class _AskAbout extends StatefulWidget {
  const _AskAbout({
    required this.name,
    required this.tile,
    required this.send,
    required this.verified,
    required this.replying,
    this.onVerify,
  });

  final String name;
  final ProfileTile tile;
  final Future<String> Function(String note) send;

  /// Their tick stands. False means the button goes to verification.
  final bool verified;

  /// This sheet answers someone who asked them, which accepts the request and
  /// opens the chat. A reply, not a request, and the button says so.
  final bool replying;

  final VoidCallback? onVerify;

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

  /// "request" when asking someone new, "reply" when answering someone who
  /// asked you, which is what asking back actually does.
  String get _what => widget.replying ? 'reply' : 'request';

  /// The way out to verification, worded for what they are doing: a bare verb
  /// either way, since what is being sent or replied to is the line they have
  /// just typed and the sheet already says whose tile it is about.
  String get _verifyLabel =>
      widget.replying ? 'Verify profile to reply' : 'Verify profile to send';

  /// Unverified: the button does not send, it takes them to verification. What
  /// they typed is not kept, which is the cost of sending them away from here.
  void _verify() {
    Navigator.of(context).pop();
    widget.onVerify?.call();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _controller.text.trim();
    // Nothing written is not a request. The button is already dimmed, so this
    // only catches the keyboard's send key.
    if (text.isEmpty) return;
    // Nor does the keyboard's send key get past the verification gate.
    if (!widget.verified) {
      _verify();
      return;
    }
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
      } else if (e.code == 'verification_required') {
        // The server is the real gate: a tick can lapse between this screen
        // loading and Send, and an older build does not know the rule at all.
        _verify();
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
    // Unverified, the button is never dimmed: it is not sending anything, it is
    // a way out to verification, and that works with the field still empty.
    final dim = widget.verified && (_sending || empty);

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
            onTap: dim ? null : (widget.verified ? _send : _verify),
            semanticLabel: widget.verified
                ? 'Send $_what to ${widget.name}'
                : _verifyLabel,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dim ? AppColors.fill2 : AppColors.fill,
                borderRadius: BorderRadius.circular(Radii.row),
              ),
              child: Text(
                !widget.verified
                    ? _verifyLabel
                    : (_sending ? 'Sending…' : 'Send $_what'),
                style: AppText.button.copyWith(
                  color: dim ? AppColors.label3 : AppColors.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
