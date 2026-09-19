import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/tile.dart';
import '../../../shared/models/tile_look.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/tiles.dart';

/// The categories the picker walks through, in a fixed order: every category
/// with at least one computed tile or one answer. Order follows the enum, so
/// an index means the same category on the way in and on the way back.
List<TileCategory> pickableCategories(
  List<Insight> candidates,
  List<PromptAnswer> answers,
) =>
    [
      for (final c in TileCategory.values)
        if (c != TileCategory.unknown &&
            (candidates.any((i) => i.category == c) ||
                answers.any((a) => a.category == c)))
          c,
    ];

/// One category of tiles, on the way in and on the way back.
///
/// Editing is this screen re-entered, not a different one. Three things differ
/// in [editing]:
///
///  * the heading says where you are rather than what to do,
///  * the foot saves and returns instead of promising a next category,
///  * the setup progress bar is hidden.
///
/// What is on the profile is one ordered list on the server. Saving a category
/// replaces that category's tiles in the list and leaves every other one where
/// the person put it.
class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({required this.index, required this.editing, super.key});

  final int index;
  final bool editing;

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

/// A choice on this screen: an insight or an answer, by its key.
typedef _Choice = ({TileKind kind, String key});

class _CategoryPageState extends ConsumerState<CategoryPage> {
  /// The server's rule too: three to a category, so every category gets a
  /// turn on the profile.
  static const _cap = 3;

  Set<_Choice>? _picked;
  bool _showCapNote = false;
  bool _saving = false;

  void _toggle(_Choice choice) {
    final picked = _picked!;
    setState(() {
      if (picked.remove(choice)) return;
      if (picked.length >= _cap) {
        _showCapNote = true;
        return;
      }
      picked.add(choice);
    });
    if (_showCapNote) {
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _showCapNote = false);
      });
    }
  }

  /// Replaces this category's tiles in the profile's list. Tiles already on
  /// the profile keep their place; new ones go to the end.
  Future<void> _save(TileCategory category, List<ProfileTile> current) async {
    final picked = _picked!;
    final keep = [
      for (final t in current)
        if (t.category != category || picked.contains((kind: t.kind, key: t.key))) t,
    ];
    final present = {for (final t in keep) (kind: t.kind, key: t.key)};
    final tiles = [
      for (final t in keep) t.toRef(),
      for (final c in picked)
        if (!present.contains(c)) {'kind': c.kind.wire, 'key': c.key},
    ];
    await ref.read(profileRepositoryProvider).setTileRefs(tiles);
    ref.invalidate(myProfileProvider);
  }

  Future<void> _next(
    TileCategory category,
    List<ProfileTile> current,
    int count,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _save(category, current);
      if (!mounted) return;
      if (widget.editing) {
        context.pop();
        return;
      }
      _advance(count);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _advance(int count) {
    final last = widget.index >= count - 1;
    unawaited(
      context.push<void>(
        last ? Routes.profileReview : Routes.pickCategoryAt(widget.index + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(candidatesProvider);
    final profile = ref.watch(myProfileProvider);
    final bank = ref.watch(promptBankProvider);
    final all = [candidates, profile, bank];
    final failed = all.where((a) => a.hasError).firstOrNull;

    if (failed != null || all.any((a) => !a.hasValue)) {
      return AppScaffold(
        navBar: AppNavBar(backLabel: 'Back', onBack: () => context.pop()),
        child: failed != null
            ? ErrorView(
                error: failed.error!,
                onRetry: () => ref
                  ..invalidate(candidatesProvider)
                  ..invalidate(myProfileProvider)
                  ..invalidate(promptBankProvider),
              )
            : const LoadingView(),
      );
    }

    final insights = candidates.requireValue;
    final answers = bank.requireValue.answers;
    final current = profile.requireValue.tiles;
    final categories = pickableCategories(insights, answers);

    if (widget.index >= categories.length) {
      return AppScaffold(
        navBar: AppNavBar(backLabel: 'Back', onBack: () => context.pop()),
        child: EmptyState(
          icon: Icons.grid_view_rounded,
          title: 'Nothing to pick from yet',
          body: 'Connect an app or answer a question, and your tiles appear '
              'here.',
          primaryLabel: 'Connect an app',
          onPrimary: () => context.push(Routes.connect),
        ),
      );
    }

    final category = categories[widget.index];
    _picked ??= {
      for (final t in current)
        if (t.category == category) (kind: t.kind, key: t.key),
    };
    final picked = _picked!;
    final inCategory = insights.where((i) => i.category == category).toList();
    final answered = answers.where((a) => a.category == category).toList();

    return AppScaffold(
      navBar: AppNavBar(
        backLabel: 'Back',
        onBack: () => context.pop(),
        trailingLabel: widget.editing ? null : 'Skip',
        onTrailing: widget.editing ? null : () => _advance(categories.length),
      ),
      footer: PrimaryButton(
        label: widget.editing
            ? 'Save ${picked.length} on your profile'
            : picked.isEmpty
                ? 'Pick at least one'
                : 'Continue with ${picked.length}',
        busy: _saving,
        onPressed: !widget.editing && picked.isEmpty
            ? null
            : () => _next(category, current, categories.length),
      ),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (!widget.editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 12),
                  child: AppProgressBar(
                    value: (widget.index + 1) / categories.length,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.titleGutter, 2, Insets.titleGutter, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.fill2,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            category.glyph,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            category.label,
                            style: AppText.title1.copyWith(fontSize: 29),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      widget.editing
                          ? '${picked.length} on your profile. Tap to add or '
                              'drop one.'
                          : 'Pick up to three.',
                      style: AppText.callout.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              BentoGrid(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 18, Insets.gutter, 0),
                children: [
                  for (final ins in inCategory)
                    _item(
                      (kind: TileKind.insight, key: ins.key),
                      size: ins.tileSize,
                      number: ins.displayValue,
                      caption: ins.caption,
                      tone: ins.tone,
                      isTrack: ins.looksLikeTrack,
                    ),
                  for (final a in answered)
                    _item(
                      (kind: TileKind.prompt, key: a.promptKey),
                      size: TileSize.wide,
                      prompt: a.question,
                      answer: a.answer,
                      tone: _toneOf(category),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.titleGutter, 16, Insets.titleGutter, 0),
                child: Text(
                  widget.editing
                      ? 'Dropping a tile takes it off your profile. It stays here, '
                          'and you can put it back any time.'
                      : 'Nothing here is public until you pick it. Anything left '
                          'unpicked never appears on your profile, but still '
                          'informs matching.',
                  style: AppText.caption,
                ),
              ),
            ],
          ),
          if (_showCapNote)
            Positioned(
              left: 26,
              right: 26,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1116),
                  borderRadius: BorderRadius.circular(Radii.row),
                  border: Border.all(color: AppColors.glassEdge),
                ),
                child: Text(
                  'Three to a category, so every category gets a turn. Drop '
                  'one to swap it.',
                  textAlign: TextAlign.center,
                  style: AppText.footnote.copyWith(color: AppColors.label),
                ),
              ),
            ),
        ],
      ),
    );
  }

  BentoItem _item(
    _Choice choice, {
    required TileSize size,
    required String tone,
    String? number,
    String? caption,
    String? prompt,
    String? answer,
    bool isTrack = false,
  }) {
    final picked = _picked!;
    return BentoItem(
      size: size,
      child: InsightTile(
        size: size,
        number: number,
        caption: caption,
        prompt: prompt,
        answer: answer,
        tone: tone,
        isTrack: isTrack,
        selected: picked.contains(choice),
        dimmed: picked.isNotEmpty && !picked.contains(choice),
        onTap: () => _toggle(choice),
      ),
    );
  }

  /// An answer tile takes its category's colour, as a derived tile would.
  String _toneOf(TileCategory category) => ProfileTile(
        kind: TileKind.prompt,
        key: '',
        category: category,
      ).tone;
}
