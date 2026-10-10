import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/typography.dart';
import '../../../../data/in_common_repository.dart';
import '../../../../data/providers.dart';
import '../../../../shared/models/consent.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/buttons.dart';
import '../../../../shared/widgets/sheets.dart';
import 'in_common_ask.dart';
import 'story_viewer.dart';

/// What tapping the ring does, from wherever the stories stand.
///
///   - ask: the question, once. A yes is granted and the stories loaded again.
///   - waiting: says who is still to answer.
///   - preparing: a model is writing the one line; wait a few seconds for it,
///     then open what there is.
///   - ready: open.
///
/// Returns the latest state, so the chat can redraw its ring.
Future<InCommon?> tapRing(
  BuildContext context,
  WidgetRef ref, {
  required String matchId,
  required InCommon current,
  void Function(bool loading)? onLoading,
}) async {
  var deck = current;
  if (deck.state == InCommonState.ask) {
    final allowed = await _ask(context, ref, deck);
    if (!allowed || !context.mounted) return deck;
    deck = await _reload(context, ref, matchId) ?? deck;
  }
  if (!context.mounted) return deck;

  if (deck.state == InCommonState.waiting) {
    await showAppSheet<void>(
      context,
      builder: (sheetContext) => InCommonWaitingCard(
        name: deck.them.firstName,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
    return deck;
  }

  if (deck.state == InCommonState.preparing) {
    onLoading?.call(true);
    deck = await _waitForThought(context, ref, matchId, deck);
    onLoading?.call(false);
  }
  if (!context.mounted || !deck.canOpen) return deck;
  await markSeen(matchId);
  if (context.mounted) await showStories(context, deck);
  return deck;
}

Future<InCommon?> _reload(BuildContext context, WidgetRef ref, String matchId) async {
  try {
    return await ref.read(inCommonRepositoryProvider).load(matchId);
  } on ApiException catch (e) {
    if (context.mounted) showAppToast(context, e.message);
    return null;
  }
}

/// A few polls, two seconds apart. The stories are usable throughout, with a
/// fixed thought, so giving up only means opening without the written one.
Future<InCommon> _waitForThought(
  BuildContext context,
  WidgetRef ref,
  String matchId,
  InCommon deck,
) async {
  var latest = deck;
  for (var i = 0; i < 6 && latest.state == InCommonState.preparing; i++) {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!context.mounted) return latest;
    try {
      latest = await ref.read(inCommonRepositoryProvider).load(matchId);
    } on ApiException {
      return latest;
    }
  }
  return latest;
}

Future<bool> _ask(BuildContext context, WidgetRef ref, InCommon deck) async {
  final ConsentNotice? notice;
  try {
    notice = (await ref.read(consentProvider.future)).noticeFor(ConsentPurpose.inCommon);
  } on ApiException catch (e) {
    if (context.mounted) showAppToast(context, e.message);
    return false;
  }
  if (notice == null || !context.mounted) return false;
  final allowed = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => InCommonAskCard(
      name: deck.them.firstName,
      themSaidYes: deck.themSaidYes,
      onAllow: () => Navigator.of(sheetContext).pop(true),
      onNotNow: () => Navigator.of(sheetContext).pop(false),
      onReadNotice: () => unawaited(_showNotice(sheetContext, notice!)),
    ),
  );
  if (allowed != true) return false;
  try {
    await ref.read(consentRepositoryProvider).grant({ConsentPurpose.inCommon: notice.version});
    ref.invalidate(consentProvider);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showAppToast(context, e.message);
    return false;
  }
}

Future<void> _showNotice(BuildContext context, ConsentNotice notice) {
  return showAppSheet<void>(
    context,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(notice.purpose.label, style: AppText.title3),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Text(notice.body, style: AppText.callout),
            ),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}

// Seen, per match, on this phone only: the ring turns grey once opened.

String _seenKey(String matchId) => 'in_common_seen:$matchId';

Future<bool> wasSeen(String matchId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey(matchId)) ?? false;
  } on Object {
    return false;
  }
}

Future<void> markSeen(String matchId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey(matchId), true);
  } on Object {
    // Without storage the ring stays coloured. Nothing is lost.
  }
}
