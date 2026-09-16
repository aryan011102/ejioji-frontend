import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';

/// The one long wait in the product, and the only place a progress ring is
/// justified: it happens once, it takes about a minute, and there is nothing
/// else to do meanwhile.
class ReadingPage extends ConsumerStatefulWidget {
  const ReadingPage({super.key});

  @override
  ConsumerState<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends ConsumerState<ReadingPage> {
  double _progress = 0.06;
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // TODO(backend): replace with the job's real progress, polled or streamed.
    _timer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted) return t.cancel();
      setState(() => _progress += 0.04);
      if (_progress >= 1) {
        t.cancel();
        setState(() {
          _progress = 1;
          _done = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      footer: _done
          ? PrimaryButton(
              label: 'Start picking',
              onPressed: () => context.push(Routes.pickCategoryAt(0)),
            )
          : null,
      child: _done ? _found() : _reading(),
    );
  }

  Widget _reading() {
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
                      value: _progress.clamp(0, 1),
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.fill2,
                      color: AppColors.fill,
                    ),
                  ),
                  Text(
                    '${(_progress * 100).clamp(0, 100).round()}%',
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
              'Receipts, listening, moving, watching. This takes about a '
              'minute and only happens once.',
              textAlign: TextAlign.center,
              style: AppText.callout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _found() {
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
                decoration: const BoxDecoration(
                  color: AppColors.fill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check,
                  size: 30,
                  color: AppColors.onAccent,
                ),
              ),
              const SizedBox(height: 18),
              Text("Everything's in.", style: AppText.title1),
              const SizedBox(height: 8),
              Text(
                'Five categories with enough in them to say something. You '
                'choose what actually appears.',
                style: AppText.callout,
              ),
            ],
          ),
        ),
        SectionGroup(
          children: [
            for (final c in Demo.categories)
              AppRow(
                label: c.name,
                subtitle: c.source,
                last: c.id == Demo.categories.last.id,
                leading: Text(c.glyph, style: const TextStyle(fontSize: 15)),
              ),
          ],
        ),
      ],
    );
  }
}
