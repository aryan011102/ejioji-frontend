import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/entry.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({required this.phone, required this.dialCode, super.key});

  final String phone;
  final String dialCode;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  static const _length = 6;

  String _code = '';
  int _secondsLeft = 24;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 24);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // TODO(backend): POST Api.verifyOtp. On success the response carries the
      // token pair and whether a profile already exists; save the tokens
      // through TokenStore and never anywhere else.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await ref
          .read(sessionProvider.notifier)
          .onSignedIn(profileComplete: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _push(String d) {
    if (_code.length >= _length) return;
    setState(() => _code += d);
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
                  const SizedBox(height: 16),
                  Center(
                    child: _secondsLeft > 0
                        ? Text(
                            'Resend in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                            style: AppText.callout,
                          )
                        : TextActionButton(
                            label: 'Resend the code',
                            onPressed: () {
                              _startCountdown();
                              showAppToast(context, 'Sent again.');
                            },
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
