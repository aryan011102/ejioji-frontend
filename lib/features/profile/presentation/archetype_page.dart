import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/models/archetype.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/tiles.dart';
import '../../onboarding/presentation/ai_consent_sheet.dart';

/// "Who your data thinks you are" (Aryan's call, 2026-10-10): four archetypes,
/// one to choose, which then sits on the back of the photo tile for anyone who
/// opens the profile. Choosing is required; setup does not go on without it.
///
/// The server writes the four. With AI allowed and something connected, a
/// model reads summaries of all of it and judges the whole person; otherwise
/// they come from a library of archetypes chosen by code, so nobody has to
/// agree to AI to get one. Refresh offers four more, a few times a day.
class ArchetypePage extends ConsumerStatefulWidget {
  const ArchetypePage({super.key});

  @override
  ConsumerState<ArchetypePage> createState() => _ArchetypePageState();
}

class _ArchetypePageState extends ConsumerState<ArchetypePage> {
  /// What refresh came back with, in place of what was first loaded.
  ArchetypeOffer? _refreshed;

  /// The option picked on screen, by id. Starts on the one already chosen.
  String? _picked;
  bool _saving = false;
  bool _refreshing = false;

  ArchetypeOffer? get _offer =>
      _refreshed ?? ref.watch(archetypesProvider).valueOrNull;

  String? _pickedIn(ArchetypeOffer offer) {
    final picked = _picked;
    if (picked != null && offer.options.any((o) => o.id == picked)) {
      return picked;
    }
    final chosen = offer.chosen;
    if (chosen == null) return null;
    for (final o in offer.options) {
      if (o.title == chosen.title && o.body == chosen.body) return o.id;
    }
    return null;
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final offer =
          await ref.read(profileRepositoryProvider).refreshArchetypes();
      if (!mounted) return;
      setState(() {
        _refreshed = offer;
        _picked = null;
      });
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _save(String optionId) async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).chooseArchetype(optionId);
      ref
        ..invalidate(myProfileProvider)
        ..invalidate(archetypesProvider);
      if (mounted) context.pop();
    } on NotFoundFailure catch (e) {
      // Refreshed somewhere else meanwhile: show what is on offer now.
      if (!mounted) return;
      showAppToast(context, e.message);
      setState(() {
        _refreshed = null;
        _picked = null;
      });
      ref.invalidate(archetypesProvider);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// AI allowed (or agreed again, under the notice that covers archetypes):
  /// the server then writes theirs from their data in place of the library's.
  Future<void> _allowAi() async {
    if (!await askForAi(context, ref) || !mounted) return;
    setState(() {
      _refreshed = null;
      _picked = null;
    });
    ref.invalidate(archetypesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(archetypesProvider);
    final offer = _offer;
    final picked = offer == null ? null : _pickedIn(offer);

    return AppScaffold(
      navBar: AppNavBar(
        backLabel: 'Back',
        onBack: () => context.pop(),
        trailingLabel: offer == null ? null : 'Refresh',
        trailingEnabled: offer != null &&
            offer.refreshesLeft > 0 &&
            !_refreshing &&
            !_saving,
        onTrailing: () => unawaited(_refresh()),
      ),
      footer: offer == null
          ? null
          : PrimaryButton(
              label: 'Use this',
              busy: _saving,
              onPressed: picked == null || _saving || _refreshing
                  ? null
                  : () => unawaited(_save(picked)),
            ),
      child: offer != null
          ? _choices(offer, picked)
          : loading.hasError
              ? ErrorView(
                  error: loading.error!,
                  onRetry: () => ref.invalidate(archetypesProvider),
                )
              : const _Writing(),
    );
  }

  Widget _choices(ArchetypeOffer offer, String? picked) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Insets.titleGutter,
        4,
        Insets.titleGutter,
        24,
      ),
      children: [
        Text('Who your data thinks you are', style: AppText.largeTitle),
        const SizedBox(height: 6),
        Text(_intro(offer), style: AppText.callout.copyWith(height: 20 / 15)),
        const SizedBox(height: 20),
        if (_refreshing)
          const SizedBox(height: 360, child: _Writing())
        else
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final o in offer.options)
                Semantics(
                  button: true,
                  selected: o.id == picked,
                  child: GestureDetector(
                    onTap: _saving ? null : () => setState(() => _picked = o.id),
                    child: ArchetypeFace(
                      archetype: Archetype(title: o.title, body: o.body),
                      selected: o.id == picked,
                      selectable: true,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Text(
          offer.refreshesLeft > 0
              ? 'Not you? Refresh for four more. '
                  '${offer.refreshesLeft} of ${offer.refreshesPerDay} left today.'
              : 'No refreshes left today. There will be more tomorrow.',
          style: AppText.caption,
        ),
        if (offer.ai != ArchetypeAi.on)
          Align(
            alignment: Alignment.centerLeft,
            child: TextActionButton(
              label: offer.ai == ArchetypeAi.off
                  ? 'Allow AI to write yours'
                  : 'Agree to the updated AI notice',
              onPressed: _saving ? null : () => unawaited(_allowAi()),
            ),
          ),
      ],
    );
  }

  static String _intro(ArchetypeOffer offer) {
    if (offer.personal) {
      return 'Written from everything you connected, taken together. Pick the '
          'one that sounds most like you. It shows on the back of your photo.';
    }
    return switch (offer.ai) {
      ArchetypeAi.on => 'These are ours for now. Connect an app, and the next '
          'ones are written from your data.',
      ArchetypeAi.outdated => 'These are ours. Our AI notice now covers '
          'archetypes: agree to it to get ones written from your data.',
      ArchetypeAi.off => 'These are ours, picked to fit what you connected. '
          'Allow AI to get ones written from your data.',
    };
  }
}

/// While the server writes them, which can take a few seconds.
class _Writing extends StatelessWidget {
  const _Writing();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 48, child: LoadingView()),
        const SizedBox(height: 12),
        Text(
          'Reading your data…',
          textAlign: TextAlign.center,
          style: AppText.callout.copyWith(color: AppColors.label2),
        ),
      ],
    );
  }
}
