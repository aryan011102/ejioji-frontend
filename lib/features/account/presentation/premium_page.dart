import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/purchases/store_purchases.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/models/premium.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// A little more access. A lot more control.
///
/// The plans come from the server. While it says `free_for_now`, starting a
/// plan grants it for that long at no charge. After that a plan is bought in
/// the App Store (one, three and twelve months renew; three days is a one-off
/// pass), and the server is asked to check the store. The app never sets
/// Premium in its own state; it asks, and reads the answer back.
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
  bool _starting = false;

  static const _features = <(IconData, String, String)>[
    (
      Icons.visibility_outlined,
      'See who viewed you',
      'Names and faces, not just a number.',
    ),
    (
      Icons.visibility_off_outlined,
      'Stealth mode',
      "Browse without appearing in anyone's feed, and without landing on "
          'their views list.',
    ),
    (
      Icons.auto_awesome,
      'Priority in feeds',
      'Your profile gets priority over others.',
    ),
    (
      Icons.bookmark_border,
      'Saved profiles',
      'Keep someone to come back to. They are never told.',
    ),
    (
      Icons.all_inclusive,
      'Unlimited Requests',
      'No daily limit, request as many people you like',
    ),
  ];

  static final _privacy = Uri.parse('https://theonebytwo.com/privacy');
  static final _terms = Uri.parse('https://theonebytwo.com/terms');
  static final _manage =
      Uri.parse('https://apps.apple.com/account/subscriptions');

  static String _subtitle(PremiumPlan plan, {required bool freeForNow}) {
    if (freeForNow) return 'Free for now';
    return plan.storeSubtitle;
  }

  Future<void> _open(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showAppToast(context, 'Could not open ${url.host}${url.path}.');
    }
  }

  Future<void> _start(PremiumStatus status) async {
    setState(() => _starting = true);
    try {
      if (status.freeForNow) {
        await ref.read(premiumRepositoryProvider).start(_plan);
        _done('onebytwo plus is on.');
      } else {
        await _buy(status);
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } on StoreFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _buy(PremiumStatus status) async {
    final plan = status.plans.where((p) => p.key == _plan).firstOrNull;
    final userId = ref.read(sessionProvider).userId;
    if (plan == null || userId == null) return;
    final outcome = await ref.read(storePurchasesProvider).buy(
          userId: userId,
          productId: plan.productId,
          renews: plan.renews,
        );
    if (outcome == BuyOutcome.cancelled) return;
    await _checkStore(
      found: 'onebytwo plus is on.',
      notYet: 'Paid. onebytwo plus turns on in a minute or two.',
    );
  }

  Future<void> _restore() async {
    final userId = ref.read(sessionProvider).userId;
    if (userId == null) return;
    setState(() => _starting = true);
    try {
      await ref.read(storePurchasesProvider).restore(userId: userId);
      await _checkStore(
        found: 'onebytwo plus restored.',
        notYet: 'Nothing to restore on this Apple ID.',
      );
    } on StoreFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// The payment is Apple's; whether it counts is the server's. If the server
  /// cannot see it yet, RevenueCat's notification will reach it shortly.
  Future<void> _checkStore({
    required String found,
    required String notYet,
  }) async {
    try {
      final synced = await ref.read(premiumRepositoryProvider).sync();
      if (synced.active) {
        _done(found);
        return;
      }
    } on ApiException {
      // Checked again when the notification lands; the page re-reads then.
    }
    ref.invalidate(premiumProvider);
    if (mounted) showAppToast(context, notYet);
  }

  void _done(String message) {
    ref
      ..invalidate(premiumProvider)
      ..invalidate(profileViewsProvider);
    if (!mounted) return;
    showAppToast(context, message);
    context.pop();
  }

  String _note(PremiumStatus? status, Map<String, String> prices) {
    if (status == null) return '';
    final ends = status.endsAt;
    final current = status.current;
    if (status.active && ends != null) {
      final day = dayLabel(ends.toLocal());
      if (!status.fromStore) {
        return 'Until $day. Nothing renews and nothing is charged.';
      }
      return current != null && current.renews
          ? 'Renews on $day. Cancel any time in the App Store.'
          : 'Until $day. Does not renew.';
    }
    if (status.freeForNow) {
      return 'Free for now. Nothing renews and nothing is charged.';
    }
    final plan = status.plans.where((p) => p.key == _plan).firstOrNull;
    if (plan == null) return '';
    return plan.terms(prices[plan.productId] ?? plan.price);
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumProvider);
    final status = premium.valueOrNull;
    final active = status?.active ?? false;
    final selling = status != null && !status.freeForNow;
    final renewing =
        status != null && status.fromStore && (status.current?.renews ?? false);
    final prices = ref.watch(storePricesProvider).valueOrNull ?? const {};

    return AppScaffold(
      navBar: AppNavBar(
        trailingLabel: 'Close',
        onTrailing: () => context.pop(),
      ),
      footer: Column(
        children: [
          PrimaryButton(
            label: active ? 'You have onebytwo plus' : 'Start onebytwo plus',
            busy: _starting,
            onPressed: status == null || active || _starting
                ? null
                : () => _start(status),
          ),
          const SizedBox(height: 9),
          Text(
            _note(status, prices),
            textAlign: TextAlign.center,
            style: AppText.micro,
          ),
          if (active && renewing)
            TextActionButton(
              label: 'Manage subscription',
              onPressed: () => _open(_manage),
            ),
          if (selling && !active)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextActionButton(
                  label: 'Restore purchases',
                  dim: true,
                  onPressed: _starting ? null : _restore,
                ),
                TextActionButton(
                  label: 'Terms',
                  dim: true,
                  onPressed: () => _open(_terms),
                ),
                TextActionButton(
                  label: 'Privacy',
                  dim: true,
                  onPressed: () => _open(_privacy),
                ),
              ],
            ),
        ],
      ),
      child: premium.hasError
          ? ErrorView(
              error: premium.error!,
              onRetry: () => ref.invalidate(premiumProvider),
            )
          : ListView(
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
                      'ONEBYTWO PLUS',
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
                  'A little more access. A lot more control.',
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
                for (final plan in status?.plans ?? const <PremiumPlan>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _PlanRow(
                      title: plan.title,
                      price: prices[plan.productId] ?? plan.price,
                      subtitle: _subtitle(
                        plan,
                        freeForNow: status?.freeForNow ?? true,
                      ),
                      badge: plan.key == 'm3' ? 'Most chosen' : null,
                      selected: _plan == plan.key,
                      onTap: active
                          ? () {}
                          : () => setState(() => _plan = plan.key),
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
