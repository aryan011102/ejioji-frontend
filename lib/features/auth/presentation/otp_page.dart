import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/entry.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({
    required this.phone,
    required this.dialCode,
    this.retryAfterSeconds = 60,
    this.debugCode,
    super.key,
  });

  final String phone;
  final String dialCode;

  /// The server's own cooldown, not a guess. A countdown that runs out before
  /// the server will send again turns Resend into an error.
  final int retryAfterSeconds;

  /// Only ever set outside deployed environments, so local development does
  /// not need a real SMS provider.
  final String? debugCode;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  static const _length = 6;

  String _code = '';
  int _secondsLeft = 0;
  bool _busy = false;
  String? _error;
  Timer? _timer;

  String get _e164 => '${widget.dialCode}${widget.phone}';

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.retryAfterSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signedIn = await ref.read(authRepositoryProvider).verifyCode(
            phone: _e164,
            code: _code,
          );
      if (!mounted) return;
      // The tokens are already stored. Where this person lands is decided by
      // whether they have a profile, which the session reads next, and the
      // router moves on its own when it resolves.
      await ref
          .read(sessionProvider.notifier)
          .onSignedIn(userId: signedIn.userId);
    } on ApiException catch (e) {
      if (!mounted) return;
      // A wrong code burns one of a few attempts. Clearing the boxes makes
      // that visible rather than leaving a half-typed code on screen that
      // looks like it might still work.
      setState(() {
        _code = '';
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _secondsLeft > 0) return;
    setState(() => _busy = true);
    try {
      final challenge =
          await ref.read(authRepositoryProvider).requestCode(_e164);
      if (!mounted) return;
      _startCountdown(challenge.retryAfter.inSeconds);
      setState(() {
        _code = '';
        _error = null;
      });
      showAppToast(context, 'Sent again.');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _push(String d) {
    if (_code.length >= _length || _busy) return;
    setState(() {
      _code += d;
      _error = null;
    });
    // Submitting on the last digit saves a tap, and the code is the only thing
    // this screen is for.
    if (_code.length == _length) unawaited(_verify());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(backLabel: 'Back', onBack: () => context.pop()),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.titleGutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Text('Enter the code', style: AppText.title1),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Sent to ${widget.dialCode} ${widget.phone}. ',
                          style: AppText.callout,
                        ),
                        TextSpan(
                          text: 'Change',
                          style: AppText.callout.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  OtpBoxes(code: _code),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style:
                          AppText.footnote.copyWith(color: AppColors.destructive),
                    ),
                  ],
                  if (widget.debugCode != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Development build: the code is ${widget.debugCode}',
                      textAlign: TextAlign.center,
                      style: AppText.micro,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: _secondsLeft > 0
                        ? Text(
                            'Resend in ${_secondsLeft ~/ 60}:'
                            '${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                            style: AppText.callout,
                          )
                        : TextActionButton(
                            label: 'Resend the code',
                            onPressed: _busy ? null : _resend,
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.accent,
                ),
              ),
            ),
          NumericKeypad(
            onDigit: _push,
            onDelete: () => setState(() {
              if (_code.isNotEmpty) {
                _code = _code.substring(0, _code.length - 1);
              }
            }),
          ),
        ],
      ),
    );
  }
}
