import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';

/// Gender, age, city, languages, education — every one of them something the
/// profile flow already asked for. A filter for something never collected is a
/// filter that returns nothing.
class FiltersPage extends ConsumerStatefulWidget {
  const FiltersPage({super.key});

  @override
  ConsumerState<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends ConsumerState<FiltersPage> {
  String _gender = 'Everyone';
  RangeValues _age = const RangeValues(24, 32);
  final _education = <String>{};
  final _languages = <String>{'English'};

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Filters',
        backLabel: 'Cancel',
        onBack: () => context.pop(),
        trailingLabel: 'Reset',
        onTrailing: () => setState(() {
          _gender = 'Everyone';
          _age = const RangeValues(24, 32);
          _education.clear();
          _languages
            ..clear()
            ..add('English');
        }),
      ),
      footer: PrimaryButton(
        label: 'Show 240 people',
        onPressed: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 24),
        children: [
          _group(
            'Gender',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in ['Everyone', 'Women', 'Men', 'Non-binary'])
                  AppChip(
                    label: g,
                    selected: _gender == g,
                    onTap: () => setState(() => _gender = g),
                  ),
              ],
            ),
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
                  onChanged: (v) => setState(() => _age = v),
                ),
              ],
            ),
          ),
          _group(
            'Languages',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in ['English', 'Hindi', 'Kannada', 'Marathi'])
                  AppChip(
                    label: l,
                    selected: _languages.contains(l),
                    onTap: () => setState(
                      () => _languages.contains(l)
                          ? _languages.remove(l)
                          : _languages.add(l),
                    ),
                  ),
              ],
            ),
            note: 'Matches anyone who speaks at least one.',
          ),
          _group(
            'Education',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in ["Bachelor's", "Master's", 'PhD', 'Diploma'])
                  AppChip(
                    label: e,
                    selected: _education.contains(e),
                    onTap: () => setState(
                      () => _education.contains(e)
                          ? _education.remove(e)
                          : _education.add(e),
                    ),
                  ),
              ],
            ),
            note: 'Left empty, education is not used to narrow anything.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.titleGutter,
            ),
            child: Text(
              'Filters narrow who appears. They never reorder anything — that '
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
