import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'buttons.dart';

/// Nothing here, and why that is fine.
///
/// Every empty state in this app says what the screen is *for* rather than
/// that it is empty, because "No messages" tells someone nothing they had not
/// already worked out.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.extra,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.fill2,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 30, color: AppColors.label3),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title2.copyWith(fontSize: 24, height: 30 / 24),
            ),
            const SizedBox(height: 9),
            Text(body, textAlign: TextAlign.center, style: AppText.callout),
            if (extra != null) ...[const SizedBox(height: 18), extra!],
            if (primaryLabel != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(label: primaryLabel!, onPressed: onPrimary),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              SecondaryButton(label: secondaryLabel!, onPressed: onSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// The loading state. Deliberately quiet — a spinner in the middle of an empty
/// screen, not a skeleton of a layout that may not arrive.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// A failure a person can act on.
///
/// It shows [ApiException.message], which is written for a person and says
/// nothing about hosts or status codes, and offers the only two useful
/// responses: try again, or go back.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Something went wrong.';
    return EmptyState(
      icon: Icons.warning_amber_rounded,
      title: 'That did not load.',
      body: message,
      primaryLabel: onRetry == null ? null : 'Try again',
      onPrimary: onRetry,
    );
  }
}

/// The card that explains a rule once, in the place the rule applies.
class NoteCard extends StatelessWidget {
  const NoteCard({
    required this.text,
    this.icon,
    this.tone = NoteTone.quiet,
    super.key,
  });

  final String text;
  final IconData? icon;
  final NoteTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      NoteTone.quiet => AppColors.fill2,
      NoteTone.gold => AppColors.goldSoft,
      NoteTone.warn => AppColors.warnSoft,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.row),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 16, color: AppColors.label3),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: AppText.footnote.copyWith(fontSize: 12.5, height: 17 / 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

enum NoteTone { quiet, gold, warn }
