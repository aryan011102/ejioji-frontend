import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/entry.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';

/// One country per line, with how many digits it expects.
///
/// The length is what makes Continue live, so a wrong-length number is caught
/// before a round trip rather than by an error from the server.
class Country {
  const Country(this.flag, this.name, this.dial, this.digits, this.groups);

  final String flag;
  final String name;
  final String dial;
  final int digits;
  final List<int> groups;
}

const _countries = [
  Country('🇮🇳', 'India', '+91', 10, [5, 5]),
  Country('🇦🇪', 'UAE', '+971', 9, [2, 3, 4]),
  Country('🇬🇧', 'United Kingdom', '+44', 10, [4, 6]),
  Country('🇺🇸', 'United States', '+1', 10, [3, 3, 4]),
  Country('🇸🇬', 'Singapore', '+65', 8, [4, 4]),
];

class PhonePage extends ConsumerStatefulWidget {
  const PhonePage({super.key});

  @override
  ConsumerState<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends ConsumerState<PhonePage> {
  int _country = 0;
  String _digits = '';
  bool _busy = false;

  Country get _c => _countries[_country];
  bool get _ready => _digits.length == _c.digits;

  String get _formatted {
    final out = StringBuffer();
    var i = 0;
    for (final size in _c.groups) {
      if (i >= _digits.length) break;
      final end = (i + size).clamp(0, _digits.length);
      if (out.isNotEmpty) out.write(' ');
      out.write(_digits.substring(i, end));
      i = end;
    }
    return out.toString();
  }

  /// What the server is sent. The digits are grouped on screen for reading;
  /// the wire always gets E.164.
  String get _e164 => '${_c.dial}$_digits';

  Future<void> _continue() async {
    if (!_ready || _busy) return;
    setState(() => _busy = true);
    try {
      // The server rate-limits per number, per device and per address. A
      // refusal here is a real answer, so the client never retries on its own:
      // every send costs an SMS, and bots hammer this endpoint.
      final challenge =
          await ref.read(authRepositoryProvider).requestCode(_e164);
      if (!mounted) return;
      context.push(
        Uri(
          path: Routes.otp,
          queryParameters: {
            'phone': _digits,
            'dial': _c.dial,
            'retry': '${challenge.retryAfter.inSeconds}',
            if (challenge.debugCode != null) 'debug': challenge.debugCode!,
          },
        ).toString(),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showAppActionSheet(
      context,
      title: 'Country',
      actions: [
        for (final c in _countries) SheetAction('${c.flag}  ${c.name}  ${c.dial}'),
      ],
    );
    if (picked != null && mounted) {
      setState(() {
        _country = picked;
        _digits = '';
      });
    }
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
                  Text("What's your number?", style: AppText.title1),
                  const SizedBox(height: 8),
                  Text(
                    "We'll text you a 6-digit code. Your number is never shown "
                    'on your profile.',
                    style: AppText.callout,
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Pressable(
                        onTap: _pickCountry,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.row,
                            borderRadius: BorderRadius.circular(Radii.row),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${_c.flag} ${_c.dial}',
                            style: AppText.body.copyWith(fontSize: 19),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: AppColors.row,
                            borderRadius: BorderRadius.circular(Radii.row),
                            border: Border.all(
                              color: AppColors.accent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _formatted,
                            style: AppText.body
                                .copyWith(fontSize: 19, letterSpacing: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              0,
              Insets.gutter,
              10,
            ),
            child: PrimaryButton(
              label: 'Continue',
              busy: _busy,
              onPressed: _ready ? _continue : null,
            ),
          ),
          NumericKeypad(
            onDigit: (d) => setState(() {
              if (_digits.length < _c.digits) _digits += d;
            }),
            onDelete: () => setState(() {
              if (_digits.isNotEmpty) {
                _digits = _digits.substring(0, _digits.length - 1);
              }
            }),
          ),
        ],
      ),
    );
  }
}
