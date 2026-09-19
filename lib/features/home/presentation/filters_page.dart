import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/feed_controller.dart';
import '../../../data/providers.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/person.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// Who is shown to you: the two filters the server has, gender ("show me") and
/// age. Read from the server and saved back to it.
///
/// "Show me" is mutual: two people are candidates only if each is in the
/// other's set, and someone who has not chosen is shown to nobody. So saving
/// this screen is also what lets anyone see you.
class FiltersPage extends ConsumerWidget {
  const FiltersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    return preferences.when(
      data: (p) => _FiltersForm(initial: p),
      loading: () => AppScaffold(
        navBar: AppNavBar(
          title: 'Filters',
          backLabel: 'Cancel',
          onBack: () => context.pop(),
        ),
        child: const LoadingView(),
      ),
      error: (e, _) => AppScaffold(
        navBar: AppNavBar(
          title: 'Filters',
          backLabel: 'Cancel',
          onBack: () => context.pop(),
        ),
        child: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(preferencesProvider),
        ),
      ),
    );
  }
}

class _FiltersForm extends ConsumerStatefulWidget {
  const _FiltersForm({required this.initial});

  final MatchPreferences initial;

  @override
  ConsumerState<_FiltersForm> createState() => _FiltersFormState();
}

class _FiltersFormState extends ConsumerState<_FiltersForm> {
  // Shown when the server has no range to give (no profile yet).
  static const _fallbackAge = RangeValues(24, 32);
  static const _sliderMin = 18.0;
  static const _sliderMax = 60.0;

  late final Set<Gender> _genders = {...widget.initial.showGenders};
  late RangeValues _age = _initialAge();
  // Untouched, a default range is sent as null, so it keeps following the
  // person's own age as their birthday moves instead of freezing today's.
  late bool _ageIsDefault = widget.initial.ageIsDefault;
  bool _saving = false;

  RangeValues _initialAge() {
    final min = widget.initial.ageMin;
    final max = widget.initial.ageMax;
    if (min == null || max == null) return _fallbackAge;
    return RangeValues(
      min.toDouble().clamp(_sliderMin, _sliderMax),
      max.toDouble().clamp(_sliderMin, _sliderMax),
    );
  }

  Future<void> _save() async {
    if (_genders.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(matchingRepositoryProvider).savePreferences(
            showGenders: [
              for (final g in Gender.values)
                if (_genders.contains(g)) g,
            ],
            ageMin: _ageIsDefault ? null : _age.start.round(),
            ageMax: _ageIsDefault ? null : _age.end.round(),
          );
      ref.invalidate(preferencesProvider);
      await ref.read(feedProvider.notifier).refresh();
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Filters',
        backLabel: 'Cancel',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Save',
        busy: _saving,
        onPressed: _genders.isEmpty ? null : _save,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 24),
        children: [
          _group(
            'Show me',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in Gender.values)
                  AppChip(
                    label: g.label,
                    selected: _genders.contains(g),
                    onTap: () => setState(
                      () => _genders.contains(g)
                          ? _genders.remove(g)
                          : _genders.add(g),
                    ),
                  ),
              ],
            ),
            note: _genders.isEmpty
                ? 'Choose at least one. Until you do, nobody is shown to you, '
                    'and you are shown to nobody.'
                : 'Only people who would also like to see you are shown.',
          ),
          _group(
            'Age',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_age.start.round()} to ${_age.end.round()}',
                  style: AppText.title3.copyWith(fontSize: 22),
                ),
                AgeRangeSlider(
                  value: _age,
                  min: _sliderMin,
                  max: _sliderMax,
                  onChanged: (v) => setState(() {
                    _age = v;
                    _ageIsDefault = false;
                  }),
                ),
              ],
            ),
            note: _ageIsDefault
                ? 'Around your own age. It moves with your birthday until you '
                    'change it.'
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.titleGutter,
            ),
            child: Text(
              'Filters narrow who appears. They never reorder anything. That '
              'is what the insights are for.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String label, Widget child, {String? note}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
            child: Text(label, style: AppText.footnote),
          ),
          child,
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 9, 2, 0),
              child: Text(note, style: AppText.caption),
            ),
        ],
      ),
    );
  }
}
