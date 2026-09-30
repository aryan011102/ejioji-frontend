import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';

/// The first screen, and the only one that renders while the keychain is read.
///
/// It shows the value of the product in one line rather than a spinner,
/// because the read is fast and a spinner on a cold start looks like a stall.
///
/// Nobody goes on without ticking the Terms and the Privacy Policy. The tick is
/// never pre-set, and the version it stands for travels with the sign-in, where
/// the server records it (`AuthRepository.termsVersion`).
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  static final _terms = Uri.parse('https://theonebytwo.com/terms');
  static final _privacy = Uri.parse('https://theonebytwo.com/privacy');

  bool _agreed = false;

  late final TapGestureRecognizer _openTerms = TapGestureRecognizer()
    ..onTap = () => _open(_terms);
  late final TapGestureRecognizer _openPrivacy = TapGestureRecognizer()
    ..onTap = () => _open(_privacy);

  @override
  void dispose() {
    _openTerms.dispose();
    _openPrivacy.dispose();
    super.dispose();
  }

  /// In the browser, never a WebView: one copy of each document, on the site.
  Future<void> _open(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showAppToast(context, 'Could not open ${url.host}${url.path}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = ref.watch(sessionProvider).stage;
    final settled = stage != SessionStage.unknown;
    final canGo = settled && _agreed;
    final link = AppText.micro.copyWith(
      fontSize: 13,
      color: AppColors.accent,
      decoration: TextDecoration.underline,
    );

    return AppScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text('theonebytwo', style: AppText.largeTitle.copyWith(fontSize: 44)),
            const SizedBox(height: 14),
            Text(
              'A profile built from what you already did, not what you would '
              'like to claim.',
              style: AppText.callout.copyWith(fontSize: 19, height: 26 / 19),
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: settled ? 1 : 0,
              duration: Motion.fade,
              child: Column(
                children: [
                  Pressable(
                    onTap: () => setState(() => _agreed = !_agreed),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Tick(on: _agreed),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: AppText.micro.copyWith(
                                  fontSize: 13,
                                  height: 18 / 13,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'I am 18 or over, and I agree to the ',
                                  ),
                                  TextSpan(
                                    text: 'Terms',
                                    style: link,
                                    recognizer: _openTerms,
                                  ),
                                  const TextSpan(text: ' and the '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: link,
                                    recognizer: _openPrivacy,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'Get started',
                    onPressed: canGo ? () => context.push(Routes.phone) : null,
                  ),
                  const SizedBox(height: 6),
                  TextActionButton(
                    label: 'I already have an account',
                    onPressed: canGo ? () => context.push(Routes.phone) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: on,
      label: 'Agree to the Terms and the Privacy Policy',
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? AppColors.fill : null,
          border: on ? null : Border.all(color: AppColors.label4, width: 1.5),
        ),
        child: on
            ? const Icon(Icons.check, size: 14, color: AppColors.onAccent)
            : null,
      ),
    );
  }
}
