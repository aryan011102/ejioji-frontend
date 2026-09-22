import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/models/connection.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

/// The one long wait in the product, and the only place a progress ring is
/// justified: it happens once, it takes about a minute, and there is nothing
/// else to do meanwhile.
///
/// The progress is the server's, polled. It used to be a timer that filled a
/// ring in three seconds regardless of what was happening, which is the kind
/// of thing that looks fine until a read fails and the app says it worked.
class ReadingPage extends ConsumerStatefulWidget {
  const ReadingPage({required this.runId, super.key});

  final String runId;

  @override
  ConsumerState<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends ConsumerState<ReadingPage> {
  IngestionRun? _run;
  ApiException? _error;
  bool _watching = true;

  @override
  void initState() {
    super.initState();
    unawaited(_watch());
  }

  Future<void> _watch() async {
    try {
      final finished = await ref.read(sourcesRepositoryProvider).watch(
            widget.runId,
            onUpdate: (run) {
              if (mounted) setState(() => _run = run);
            },
          );
      if (!mounted) return;
      setState(() {
        _run = finished;
        _watching = false;
      });
      // The tiles are recomputed after the records commit, so they only exist
      // once the run is done.
      ref
        ..invalidate(candidatesProvider)
        ..invalidate(connectionsProvider)
        ..invalidate(myProfileProvider);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _watching = false;
        });
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return AppScaffold(
        child: ErrorView(
          error: error,
          onRetry: () {
            setState(() {
              _error = null;
              _watching = true;
            });
            unawaited(_watch());
          },
        ),
      );
    }

    final run = _run;
    final finished = run != null && run.isFinished;

    return AppScaffold(
      // Nothing is blocked on this. Someone who wants to get on with it can,
      // and the tiles appear when the read lands.
      // Either way it goes back to the list it came from. Tiles are picked
      // after connecting, not per app: in onboarding that is the connect
      // screen's Next, and from "Your insights" it is the app's own card.
      navBar: _watching
          ? AppNavBar(trailingLabel: 'Later', onTrailing: _back)
          : const AppNavBar(),
      footer: finished ? PrimaryButton(label: 'Done', onPressed: _back) : null,
      child: finished ? _result(run) : _reading(run),
    );
  }

  Widget _reading(IngestionRun? run) {
    final progress = run?.progress ?? 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: CircularProgressIndicator(
                      // Indeterminate until the server has told us how many
                      // steps there are. A ring sitting at 6% for a minute
                      // reads as stuck.
                      value: run == null || run.steps.isEmpty ? null : progress,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.fill2,
                      color: AppColors.fill,
                    ),
                  ),
                  if (run != null && run.steps.isNotEmpty)
                    Text(
                      '${(progress * 100).clamp(0, 100).round()}%',
                      style: AppText.title1.copyWith(fontSize: 26),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Reading what you already did',
              textAlign: TextAlign.center,
              style: AppText.title3.copyWith(fontSize: 21),
            ),
            const SizedBox(height: 7),
            Text(
              'This takes about a minute and only happens once. We read it, '
              'work out what it says, and give the key straight back.',
              textAlign: TextAlign.center,
              style: AppText.callout,
            ),
            if (run != null && run.steps.isNotEmpty) ...[
              const SizedBox(height: 22),
              for (final step in run.steps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        switch (step.status) {
                          StepStatus.done => Icons.check_circle,
                          StepStatus.failed => Icons.error_outline,
                          _ => Icons.circle_outlined,
                        },
                        size: 15,
                        color: switch (step.status) {
                          StepStatus.done => AppColors.ok,
                          StepStatus.failed => AppColors.destructive,
                          _ => AppColors.label3,
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        step.status == StepStatus.done && step.itemCount > 0
                            ? '${step.name} · ${step.itemCount}'
                            : step.name,
                        style: AppText.footnote,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// What came back.
  ///
  /// Thin is not a failure and neither is empty. Both get a plain count and a
  /// way forward, because the alternative is generating a confident profile
  /// from four songs, which is the single worst thing this product could do.
  Widget _result(IngestionRun run) {
    final problem = run.problem;
    final ok = problem == null && run.status != RunStatus.empty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.titleGutter,
            26,
            Insets.titleGutter,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ok ? AppColors.fill : AppColors.fill2,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  ok ? Icons.check : Icons.info_outline,
                  size: 30,
                  color: ok ? AppColors.onAccent : AppColors.label2,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                switch (run.sufficiency) {
                  _ when problem != null => 'That did not finish.',
                  Sufficiency.strong => 'Plenty to work with.',
                  Sufficiency.moderate => 'Enough to say something.',
                  Sufficiency.weak => 'Not very much, honestly.',
                  _ => 'We did not find anything.',
                },
                style: AppText.title1,
              ),
              const SizedBox(height: 8),
              Text(
                problem ??
                    (run.itemsFound == 0
                        ? 'There was nothing here for us to read. Connecting '
                            'another source, or answering a few questions, '
                            'works just as well.'
                        : 'We read ${run.itemsFound} things from '
                            '${run.provider.label}. You choose what actually '
                            'appears on your profile.'),
                style: AppText.callout,
              ),
              if (run.sufficiency == Sufficiency.weak) ...[
                const SizedBox(height: 16),
                const NoteCard(
                  icon: Icons.info_outline,
                  text: 'We would rather say little than make something up, so '
                      'there will not be many tiles from this. Another source '
                      'or a few questions will fill it out.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
