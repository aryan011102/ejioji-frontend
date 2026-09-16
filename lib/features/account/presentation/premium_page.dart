import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';

/// Four things, and none of them unlock something we took away.
///
/// Nothing is capped on free — anyone can write to anyone, and replying stays
/// optional whether or not somebody pays. A paywall that removes an artificial
/// limit teaches people the product was broken on purpose.
class PremiumPage extends ConsumerStatefulWidget {
  const PremiumPage({super.key});

  @override
  ConsumerState<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends ConsumerState<PremiumPage> {
  String _plan = 'm3';

  static const _features = <(IconData, String, String)>[
    (
      Icons.visibility_outlined,
      'See who viewed you',
      'Names and faces, not just a number.',
    ),
    (
      Icons.visibility_off_outlined,
      'Stealth mode',
      "Browse without appearing in anyone's feed — and without landing on "
          'their views list.',
    ),
    (
      Icons.auto_awesome,
      'Priority in feeds',
      'Your profile is shown to more people, sooner.',
    ),
    (
      Icons.star_outline,
      'More insights',
      'Put more of what you picked on the wall.',
    ),
  ];

  static const _plans = <(String, String, String, String, String?)>[
    ('m1', '1 month', '₹799', '₹799 a month', null),
    ('m3', '3 months', '₹1,799', '₹600 a month', 'Most chosen'),
    ('m12', '12 months', '₹4,999', '₹417 a month', null),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        trailingLabel: 'Close',
        onTrailing: () => context.pop(),
      ),
      footer: Column(
        children: [
          PrimaryButton(
            label: 'Start Premium',
            onPressed: () {
              // TODO(backend): hand off to the store, then POST the receipt to
              // Api.purchase. Entitlement is decided server-side — the client
              // never grants itself Premium on a local receipt.
              ref.read(sessionProvider.notifier).onPremium(active: true);
              context.pop();
            },
          ),
          const SizedBox(height: 9),
          Text(
            'Renews until cancelled · cancel any time in the App Store',
            textAlign: TextAlign.center,
            style: AppText.micro,
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.titleGutter,
              4,
              Insets.titleGutter,
              22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'EJIOJI PREMIUM',
                      style: AppText.micro.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Four things, and none of them unlock something we took '
                  'away.',
                  style: AppText.title1.copyWith(fontSize: 31, height: 37 / 31),
                ),
              ],
            ),
          ),
          SectionGroup(
            children: [
              for (final (icon, title, body) in _features)
                AppRow(
                  label: title,
                  subtitle: body,
                  last: title == _features.last.$2,
                  leading: Icon(icon, size: 18, color: AppColors.label2),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Column(
              children: [
                for (final (id, title, price, sub, badge) in _plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _PlanRow(
                      title: title,
                      price: price,
                      subtitle: sub,
                      badge: badge,
                      selected: _plan == id,
                      onTap: () => setState(() => _plan = id),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.row,
              borderRadius: BorderRadius.circular(Radii.row),
              border: Border.all(
                color: selected ? AppColors.fill : AppColors.hairline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.fill : null,
                    border: selected
                        ? null
                        : Border.all(color: AppColors.label4, width: 1.5),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.onAccent,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.bodyStrong),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: AppText.caption.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Text(price, style: AppText.bodyStrong),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -8,
              right: 14,
              child: Container(
                height: 19,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: AppText.micro.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
