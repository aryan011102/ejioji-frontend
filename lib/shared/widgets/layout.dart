import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'pressable.dart';

/// Every screen's shell.
///
/// It owns the background, the safe areas and the footer, so no page has to
/// remember any of them. [footer] sits above the home indicator with a hairline
/// over it — the pattern every screen with a primary action uses.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.navBar,
    this.footer,
    this.tabBar,
    this.background,
    super.key,
  });

  final Widget child;
  final PreferredSizeWidget? navBar;
  final Widget? footer;

  /// Passed rather than composed so the platform decides how it is anchored:
  /// floating over the content on iOS, docked below it on Android.
  final Widget? tabBar;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (navBar != null) navBar!,
        Expanded(child: child),
        if (footer != null)
          Container(
            decoration: const BoxDecoration(
              color: AppColors.group,
              border: Border(
                top: BorderSide(color: AppColors.separator, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              10,
              Insets.gutter,
              10,
            ),
            child: footer,
          ),
      ],
    );

    return Scaffold(
      backgroundColor: background ?? AppColors.group,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: tabBar == null,
        child: body,
      ),
      bottomNavigationBar: tabBar,
      extendBody: true,
    );
  }
}

/// A pushed page's bar.
///
/// The back label names its parent — `‹ Settings`, not `‹ Back` — because on a
/// tree this deep "back" answers the wrong question. [trailing] is the one
/// action a pushed page is allowed, usually Save.
class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({
    this.title,
    this.onTitle,
    this.backLabel,
    this.onBack,
    this.leadingLabel,
    this.onLeading,
    this.trailingLabel,
    this.onTrailing,
    this.trailingEnabled = true,
    super.key,
  });

  final String? title;

  /// Makes the title itself the way to the thing it names, which on a
  /// conversation is the person. Null leaves it as plain text.
  final VoidCallback? onTitle;

  final String? backLabel;
  final VoidCallback? onBack;

  /// A plain word on the left with no chevron, for a screen you leave rather
  /// than go back from: Cancel on something being composed.
  final String? leadingLabel;
  final VoidCallback? onLeading;
  final String? trailingLabel;
  final VoidCallback? onTrailing;
  final bool trailingEnabled;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.group,
        border: Border(
          bottom: BorderSide(color: AppColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: leadingLabel != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Pressable(
                      onTap: onLeading ?? () => Navigator.of(context).maybePop(),
                      semanticLabel: leadingLabel!,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
                        child: Text(
                          leadingLabel!,
                          style: AppText.navAction
                              .copyWith(color: AppColors.accent),
                        ),
                      ),
                    ),
                  )
                : backLabel == null
                    ? null
                    : Pressable(
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    semanticLabel: 'Back to $backLabel',
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chevron_left,
                            size: 26,
                            color: AppColors.accent,
                          ),
                          Flexible(
                            child: Text(
                              backLabel!,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.navAction
                                  .copyWith(color: AppColors.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: onTitle == null
                ? Text(
                    title ?? '',
                    textAlign: TextAlign.center,
                    style: AppText.navTitle,
                  )
                : Pressable(
                    onTap: onTitle,
                    semanticLabel: 'Open ${title ?? 'this'} profile',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: AppText.navTitle,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.label3,
                        ),
                      ],
                    ),
                  ),
          ),
          SizedBox(
            width: 112,
            child: trailingLabel == null
                ? null
                : Align(
                    alignment: Alignment.centerRight,
                    child: Pressable(
                      onTap: trailingEnabled ? onTrailing : null,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
                        child: Text(
                          trailingLabel!,
                          style: AppText.navAction.copyWith(
                            fontWeight: FontWeight.w600,
                            color: trailingEnabled
                                ? AppColors.accent
                                : AppColors.label4,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The large title at the top of a root screen.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.text, {this.subtitle, super.key});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.titleGutter,
        2,
        Insets.titleGutter,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppText.largeTitle),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: AppText.callout),
          ],
        ],
      ),
    );
  }
}

/// A grouped list section: caps header, rounded plate, optional footnote.
///
/// The footnote is for a rule that needs stating once — what blocking does,
/// what unlinking keeps. It is not a place for encouragement.
class SectionGroup extends StatelessWidget {
  const SectionGroup({
    required this.children,
    this.header,
    this.footer,
    super.key,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
              child: Text(header!.toUpperCase(), style: AppText.groupHeader),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.row,
              borderRadius: BorderRadius.circular(Radii.row),
              border: Border.all(color: AppColors.hairline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.row),
              child: Column(children: children),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(footer!, style: AppText.caption),
            ),
        ],
      ),
    );
  }
}

/// One row shape for the whole settings tree.
///
/// `value` is the quiet right-hand answer, `chip` is the premium lock, and
/// `control` replaces the chevron when the row is a switch rather than a door.
class AppRow extends StatelessWidget {
  const AppRow({
    required this.label,
    this.leading,
    this.subtitle,
    this.value,
    this.premium = false,
    this.control,
    this.destructive = false,
    this.last = false,
    this.onTap,
    super.key,
  });

  final String label;
  final Widget? leading;
  final String? subtitle;
  final String? value;
  final bool premium;
  final Widget? control;
  final bool destructive;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox(width: 29, height: 29, child: Center(child: leading)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppText.body.copyWith(
                    color:
                        destructive ? AppColors.destructive : AppColors.label,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: AppText.caption),
                ],
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                value!,
                style: AppText.callout.copyWith(color: AppColors.label3),
              ),
            ),
          if (premium) ...[const SizedBox(width: 8), const PremiumChip()],
          if (control != null) ...[const SizedBox(width: 8), control!],
          if (onTap != null && control == null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.label4,
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: onTap == null
              ? row
              : PressableRow(onTap: onTap, child: row),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(left: 55),
            child: Divider(height: 0.5, thickness: 0.5, color: AppColors.separator),
          ),
      ],
    );
  }
}

/// The lock on a row a free account cannot use. It replaces the switch rather
/// than sitting next to a switch that does nothing.
class PremiumChip extends StatelessWidget {
  const PremiumChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fill2,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        'PREMIUM',
        style: AppText.micro.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// A rounded icon plate — the 29pt square in a settings row, or the 34–40pt
/// one on a card.
class IconPlate extends StatelessWidget {
  const IconPlate(
    this.icon, {
    this.size = 29,
    this.background = AppColors.fill2,
    this.foreground = AppColors.label2,
    this.radius = 8,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.58, color: foreground),
    );
  }
}
