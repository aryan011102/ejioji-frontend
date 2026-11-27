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
import '../../../shared/models/enums.dart';
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
/// the App Store or Google Play (one, three and twelve months renew; three days is a one-off
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
  /// The plan tapped on this page; null until one is. See [_selected].
  String? _plan;
  bool _starting = false;

  /// The plan the page is on. Someone who already renews a plan starts on
  /// theirs, so the button manages it; anyone else starts on three months.
  ///
  /// Every plan stays tappable and buyable while one is running: App Review
  /// buys each product on one account, and a page that went dead after the
  /// first purchase was rejected as "the purchase button is unresponsive"
  /// (2.1(b), 12 Nov 2026).
  String _selected(PremiumStatus? status) {
    final tapped = _plan;
    if (tapped != null) return tapped;
    final current = status?.current;
    if (status != null &&
        status.active &&
        status.fromStore &&
        current != null &&
        current.renews) {
      return current.key;
    }
    return 'm3';
  }

  /// Women only, so it is left off the list for everyone else.
  static const _stealth = (
    Icons.visibility_off_outlined,
    'Stealth mode',
    "Browse without appearing in anyone's feed, and without landing on "
        'their views list.',
  );

  static const _features = <(IconData, String, String)>[
    (
      Icons.visibility_outlined,
      'See who viewed you',
      'Names and faces, not just a number.',
    ),
    _stealth,
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

  /// The store on this phone: the App Store on an iPhone, Google Play on
  /// Android.
  Store get _here => ref.read(storePurchasesProvider).store ?? Store.appStore;

  /// The store the running plan was bought in, which is where it is managed
  /// and cancelled, whichever phone this is.
  Store _managedBy(PremiumStatus status) =>
      Store.fromSource(status.source) ?? _here;

  Uri _manage(PremiumStatus status) =>
      _managedBy(status).manage(productId: status.current?.productId);

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
        await ref.read(premiumRepositoryProvider).start(_selected(status));
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
    final key = _selected(status);
    final plan = status.plans.where((p) => p.key == key).firstOrNull;
    final userId = ref.read(sessionProvider).userId;
    if (plan == null) {
      if (mounted) showAppToast(context, "That plan isn't available right now.");
      return;
    }
    if (userId == null) {
      if (mounted) showAppToast(context, 'Sign in again to buy onebytwo plus.');
      return;
    }
    final here = _here;
    final current = status.current;
    final renewing = status.active &&
        status.fromStore &&
        current != null &&
        current.renews;
    // A subscription renewing in the other store can't be switched from
    // here: buying would start a second one alongside it.
    if (renewing && plan.renews && _managedBy(status) != here) {
      final there = _managedBy(status);
      if (mounted) {
        showAppToast(
          context,
          'Your plan renews in ${there.name}. Change it on your '
          '${there.device}, or cancel it there first.',
        );
      }
      return;
    }
    final outcome = await ref.read(storePurchasesProvider).buy(
          userId: userId,
          productId: plan.productId,
          renews: plan.renews,
          replacing: renewing ? current.productId : null,
        );
    if (outcome == BuyOutcome.cancelled) return;
    await _checkStore(
      found: status.active
          ? 'Done. ${here.title} has your new plan.'
          : 'onebytwo plus is on.',
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
        notYet: 'Nothing to restore on this ${_here.account}.',
      );
    } on StoreFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// The payment is the store's; whether it counts is the server's. If the server
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
    final key = _selected(status);
    final plan = status.plans.where((p) => p.key == key).firstOrNull;
    final owned = current != null && current.key == key;
    if (status.active &&
        ends != null &&
        (owned || status.freeForNow || plan == null)) {
      final day = dayLabel(ends.toLocal());
      if (!status.fromStore) {
        return 'Until $day. Nothing renews and nothing is charged.';
      }
      return current != null && current.renews
          ? 'Renews on $day. Cancel any time in ${_managedBy(status).name}.'
          : 'Until $day. Does not renew.';
    }
    if (status.freeForNow) {
      return 'Free for now. Nothing renews and nothing is charged.';
    }
    if (plan == null) return '';
    final terms = plan.terms(
      prices[plan.productId] ?? plan.price,
      account: _here.account,
    );
    if (!status.active) return terms;
    if (!plan.renews) {
      return '$terms It runs alongside the plan you have, not after it.';
    }
    if (status.fromStore &&
        current != null &&
        current.renews &&
        _managedBy(status) == _here) {
      return '$terms ${_here.title} moves you over and credits any unused '
          'time.';
    }
    return terms;
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumProvider);
    final status = premium.valueOrNull;
    final active = status?.active ?? false;
    final selling = status != null && !status.freeForNow;
    final renewing =
        status != null && status.fromStore && (status.current?.renews ?? false);
    final current = active ? status?.current : null;
    final selected = _selected(status);
    final chosen = status?.plans.where((p) => p.key == selected).firstOrNull;
    // On the plan they already have.
    final owned = current != null && current.key == selected;
    // Free plans cannot stack (the server refuses one while another runs);
    // bought ones can: switching a subscription, or a pass on top.
    final canBuy = status != null && (!active || (selling && !owned));
    // On the subscription they renew: the button manages it in the App Store.
    final manages = owned && renewing;
    final String label;
    if (!active) {
      label = 'Start onebytwo plus';
    } else if (manages) {
      label = 'Manage subscription';
    } else if (canBuy && chosen != null) {
      label = !chosen.renews
          ? 'Buy the ${chosen.count}-${chosen.unit} pass'
          : renewing
              ? 'Switch to ${chosen.title}'
              : 'Get ${chosen.title}';
    } else {
      label = 'You have onebytwo plus';
    }
    final prices = ref.watch(storePricesProvider).valueOrNull ?? const {};
    final isWoman = ref.watch(myProfileProvider).valueOrNull?.profile?.gender ==
        Gender.woman;
    final features = [
      for (final f in _features)
        if (f != _stealth || isWoman) f,
    ];

    return AppScaffold(
      navBar: AppNavBar(
        trailingLabel: 'Close',
        onTrailing: () => context.pop(),
      ),
      footer: Column(
        children: [
          PrimaryButton(
            label: label,
            busy: _starting,
            onPressed: status == null || _starting
                ? null
                : manages
                    ? () => _open(_manage(status))
                    : canBuy
                        ? () => _start(status)
                        : null,
          ),
          const SizedBox(height: 9),
          Text(
            _note(status, prices),
            textAlign: TextAlign.center,
            style: AppText.micro,
          ),
          if (renewing && !manages)
            TextActionButton(
              label: 'Manage subscription',
              onPressed: () => _open(_manage(status)),
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
                  'A little more access.\nA lot more control.',
                  style: AppText.title1.copyWith(fontSize: 31, height: 37 / 31),
                ),
              ],
            ),
          ),
          SectionGroup(
            children: [
              for (final (icon, title, body) in features)
                AppRow(
                  label: title,
                  subtitle: body,
                  last: title == features.last.$2,
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
                      badge: current?.key == plan.key
                          ? 'Your plan'
                          : plan.key == 'm3'
                              ? 'Most chosen'
                              : null,
                      selected: selected == plan.key,
                      onTap: () => setState(() => _plan = plan.key),
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
