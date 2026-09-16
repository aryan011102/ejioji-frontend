import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/tiles.dart';

/// One category of insights, on the way in and on the way back.
///
/// Editing insights is this screen re-entered, not a different one: the thing
/// being changed is a tile — a picture with a number on it — and a list of
/// rows cannot show one. Three things differ in [editing]:
///
///  * the heading says where you are rather than what to do,
///  * the foot saves and returns to the accounts page instead of promising a
///    next category,
///  * the setup progress bar is hidden, because it measured a journey through
///    all of them and this is not that.
///
/// Refresh and unlink are deliberately **not** here — they belong to the
/// account, and they live on the page in front of this one.
class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({required this.index, required this.editing, super.key});

  final int index;
  final bool editing;

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  static const _cap = 3;

  late Set<String> _picked;
  final _withMedia = <String>{};
  bool _showCapNote = false;

  DemoCategory get _category => Demo.categories[widget.index];
  bool get _isLast => widget.index == Demo.categories.length - 1;

  @override
  void initState() {
    super.initState();
    _picked = widget.editing ? {..._category.picked} : <String>{};
  }

  void _toggle(String id) {
    setState(() {
      if (_picked.remove(id)) return;
      if (_picked.length >= _cap) {
        _showCapNote = true;
        return;
      }
      _picked.add(id);
    });
    if (_showCapNote) {
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _showCapNote = false);
      });
    }
  }

  Future<void> _media(String id) async {
    final choice = await showAppActionSheet(
      context,
      title: 'Put something behind this',
      message: 'It sits under the number, on your profile only if this insight '
          'is picked.',
      actions: const [
        SheetAction('Photo Library', icon: Icons.photo_library_outlined),
        SheetAction('Take Photo or Video', icon: Icons.photo_camera_outlined),
        SheetAction("Remove what's there", destructive: true),
      ],
    );
    if (choice == null || !mounted) return;
    setState(() => choice == 2 ? _withMedia.remove(id) : _withMedia.add(id));
  }

  void _next() {
    if (widget.editing) {
      context.pop();
      return;
    }
    // TODO(backend): PATCH Api.picks with the ids this category settled on.
    unawaited(
      context.push<void>(
        _isLast
            ? Routes.profileReview
            : Routes.pickCategoryAt(widget.index + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = _category;

    return AppScaffold(
      navBar: AppNavBar(
        backLabel: 'Back',
        onBack: () => context.pop(),
        trailingLabel: widget.editing ? 'Done' : 'Skip',
        onTrailing: widget.editing ? () => context.pop() : _next,
      ),
      footer: PrimaryButton(
        label: widget.editing
            ? 'Save ${_picked.length} on your profile'
            : _picked.isEmpty
                ? 'Pick at least one'
                : 'Continue with ${_picked.length}',
        onPressed: !widget.editing && _picked.isEmpty ? null : _next,
      ),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (!widget.editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    0,
                    Insets.gutter,
                    12,
                  ),
                  child: AppProgressBar(
                    value: (widget.index + 1) / Demo.categories.length,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.titleGutter,
                  2,
                  Insets.titleGutter,
                  0,
                ),
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
                            cat.glyph,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cat.name,
                            style: AppText.title1.copyWith(fontSize: 29),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      widget.editing
                          ? '${_picked.length} on your profile. Tap to add or '
                              'drop one, or change what sits behind it.'
                          : '${cat.source}. Pick up to three, and put a photo '
                              'or video behind any of them.',
                      style: AppText.callout.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              BentoGrid(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  18,
                  Insets.gutter,
                  0,
                ),
                children: [
                  for (final ins in cat.insights)
                    BentoItem(
                      size: ins.size,
                      child: InsightTile(
                        size: ins.size,
                        number: ins.number,
                        caption: ins.caption,
                        prompt: ins.prompt,
                        answer: ins.answer,
                        tone: ins.tone,
                        hasMedia: ins.media || _withMedia.contains(ins.id),
                        isTrack: ins.track,
                        selected: _picked.contains(ins.id),
                        dimmed: _picked.isNotEmpty && !_picked.contains(ins.id),
                        onTap: () => _toggle(ins.id),
                        onMedia: _picked.contains(ins.id)
                            ? () => _media(ins.id)
                            : null,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.titleGutter,
                  16,
                  Insets.titleGutter,
                  0,
                ),
                child: Text(
                  widget.editing
                      ? 'Dropping a tile takes it off your profile. It stays in '
                          'your picks, and you can put it back any time.'
                      : 'Nothing here is public until you pick it. Anything '
                          'left unpicked stays in your profile\'s data but '
                          'never appears on it.',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
}
