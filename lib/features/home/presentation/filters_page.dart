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
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// Who is shown to you: gender ("show me"), age, city, languages and
/// education. Read from the server and saved back to it.
///
/// Every one of them is mutual: two people are candidates only if each is in
/// the other's sets. So saving this screen is also what lets anyone see you,
/// and narrowing a filter narrows who can see you by the same amount.
///
/// All but gender narrow nothing while they are empty, and an empty city
/// means your own city. The chip lists come from `/profile/options` rather
/// than from the enums, so a new city or language needs no app release.
class FiltersPage extends ConsumerWidget {
  const FiltersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final options = ref.watch(profileOptionsProvider);

    Widget shell(Widget child) => AppScaffold(
          navBar: AppNavBar(
            title: 'Filters',
            backLabel: 'Cancel',
            onBack: () => context.pop(),
          ),
          child: child,
        );

    // Either one failing is the same failure to the person: the screen cannot
    // be filled in. Retry reloads both rather than leaving one stale.
    final failure = preferences.error ?? options.error;
    if (failure != null) {
      return shell(
        ErrorView(
          error: failure,
          onRetry: () {
            ref.invalidate(preferencesProvider);
            ref.invalidate(profileOptionsProvider);
          },
        ),
      );
    }
    final saved = preferences.valueOrNull;
    final lists = options.valueOrNull;
    if (saved == null || lists == null) return shell(const LoadingView());
    return _FiltersForm(initial: saved, options: lists);
  }
}

class _FiltersForm extends ConsumerStatefulWidget {
  const _FiltersForm({required this.initial, required this.options});

  final MatchPreferences initial;
  final ProfileOptions options;

  @override
  ConsumerState<_FiltersForm> createState() => _FiltersFormState();
}

class _FiltersFormState extends ConsumerState<_FiltersForm> {
  // Shown when the server has no range to give (no profile yet).
  static const _fallbackAge = RangeValues(24, 32);
  static const _sliderMin = 18.0;
  static const _sliderMax = 60.0;

  late final Set<Gender> _genders = {...widget.initial.showGenders};
  late final Set<City> _cities = {...widget.initial.cities};
  late final Set<Language> _languages = {...widget.initial.languages};
  late final Set<Education> _education = {...widget.initial.educationLevels};
  late RangeValues _age = _initialAge();
  // Untouched, a default range is sent as null, so it keeps following the
  // person's own age as their birthday moves instead of freezing today's.
  late bool _ageIsDefault = widget.initial.ageIsDefault;
  // What Reset goes back to. A range the person already narrowed is not a
  // default, so in that case Reset falls back to the plain 24-32.
  late final RangeValues _defaultAge =
      widget.initial.ageIsDefault ? _initialAge() : _fallbackAge;
  bool _saving = false;

  // The design says "Women" and "Men" where a profile says "Woman" and "Man":
  // this is a set of people to show, not one person's own answer.
  static const _genderLabels = <Gender, String>{
    Gender.woman: 'Women',
    Gender.man: 'Men',
    Gender.nonBinary: 'Non-binary',
  };

  /// Every gender at once. The server has no "everyone" value, so this is the
  /// full set rather than a fourth option.
  bool get _isEveryone => _genders.length == Gender.values.length;

  /// The chips to show, in the order the server gave them, dropping any value
  /// this build does not know. A list that grew server-side shows what it can
  /// rather than failing on the one entry it has never heard of.
  List<(City, String)> get _cityChips => [
        for (final o in widget.options.cities)
          if (City.parse(o.key) case final c when c != City.unknown)
            (c, o.label),
      ];

  List<(Language, String)> get _languageChips => [
        for (final o in widget.options.languages)
          if (Language.parse(o.key) case final l?) (l, o.label),
      ];

  List<(Education, String)> get _educationChips => [
        for (final o in widget.options.educations)
          if (Education.parse(o.key) case final e?) (e, o.label),
      ];

  RangeValues _initialAge() {
    final min = widget.initial.ageMin;
    final max = widget.initial.ageMax;
    if (min == null || max == null) return _fallbackAge;
    return RangeValues(
      min.toDouble().clamp(_sliderMin, _sliderMax),
      max.toDouble().clamp(_sliderMin, _sliderMax),
    );
  }

  void _reset() => setState(() {
        _genders
          ..clear()
          ..addAll(Gender.values);
        _age = _defaultAge;
        _ageIsDefault = true;
        // Back to narrowing nothing, which for city means your own city.
        _cities.clear();
        _languages.clear();
        _education.clear();
      });

  /// Out of Everyone, the first tap narrows to that one gender rather than
  /// dropping it out of a set the person never picked chip by chip.
  void _tapGender(Gender g) => setState(() {
        if (_isEveryone) {
          _genders
            ..clear()
            ..add(g);
        } else if (_genders.contains(g)) {
          _genders.remove(g);
        } else {
          _genders.add(g);
        }
      });

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
            cities: [
              for (final (city, _) in _cityChips)
                if (_cities.contains(city)) city,
            ],
            languages: [
              for (final (language, _) in _languageChips)
                if (_languages.contains(language)) language,
            ],
            educationLevels: [
              for (final (level, _) in _educationChips)
                if (_education.contains(level)) level,
            ],
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
        trailingLabel: 'Reset',
        trailingEnabled: !_saving,
        onTrailing: _reset,
      ),
      footer: PrimaryButton(
        label: 'Show people',
        busy: _saving,
        onPressed: _genders.isEmpty ? null : _save,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 24),
        children: [
          _group(
            'Gender',
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                AppChip(
                  label: 'Everyone',
                  selected: _isEveryone,
                  onTap: () => setState(
                    () => _genders
                      ..clear()
                      ..addAll(Gender.values),
                  ),
                ),
                for (final g in Gender.values)
                  AppChip(
                    label: _genderLabels[g]!,
                    selected: !_isEveryone && _genders.contains(g),
                    onTap: () => _tapGender(g),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_age.start.round()} to ${_age.end.round()}',
                      style: AppText.title3.copyWith(fontSize: 22),
                    ),
                    const Spacer(),
                    Text('years', style: AppText.caption),
                  ],
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
          _group(
            'City',
            _chipWrap([
              for (final (city, label) in _cityChips)
                (label, _cities.contains(city), () => _toggle(_cities, city)),
            ]),
            note: _cities.isEmpty
                ? 'Left empty, you are shown people in your own city.'
                : 'Your own city is always included. Someone in another city '
                    'sees you only if they picked yours too.',
          ),
          _group(
            'Languages',
            _chipWrap([
              for (final (language, label) in _languageChips)
                (
                  label,
                  _languages.contains(language),
                  () => _toggle(_languages, language),
                ),
            ]),
            note: 'Matches anyone who speaks at least one.',
          ),
          _group(
            'Education',
            _chipWrap([
              for (final (level, label) in _educationChips)
                (
                  label,
                  _education.contains(level),
                  () => _toggle(_education, level),
                ),
            ]),
            note: 'Left empty, education is not used to narrow anything.',
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

  void _toggle<T>(Set<T> chosen, T value) => setState(
        () => chosen.contains(value) ? chosen.remove(value) : chosen.add(value),
      );

  Widget _chipWrap(List<(String, bool, VoidCallback)> chips) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final (label, selected, onTap) in chips)
            AppChip(label: label, selected: selected, onTap: onTap),
        ],
      );

  Widget _group(String label, Widget child, {String? note}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 18),
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
