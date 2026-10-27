import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../models/enums.dart';
import '../models/profile.dart';
import '../models/tile.dart';
import 'pressable.dart';
import 'sheets.dart';

/// Where someone lives: every city, under its country, with a search box.
///
/// Thirty-odd cities in seven countries is too many to scroll through, so
/// typing narrows the list, by city or by country, and by the names people
/// still use (Bangalore, Gurgaon, NYC, San Jose). A server from before cities
/// abroad sends no countries, and then it is one plain list. Null when the
/// sheet is dismissed.
Future<City?> pickCity(BuildContext context, ProfileOptions options) {
  final groups = options.countries.isNotEmpty
      ? [for (final c in options.countries) (c.key, c.label, c.cities)]
      : [('', '', options.cities)];
  return showAppSheet<City>(
    context,
    builder: (_) => _CityPicker(groups: groups),
  );
}

/// Other names a city goes by, matched as well as its label. Lowercase.
const _aliases = <String, List<String>>{
  'bengaluru': ['bangalore'],
  'mumbai': ['bombay', 'navi mumbai', 'thane'],
  'delhi_ncr': ['delhi', 'new delhi', 'gurgaon', 'gurugram', 'noida', 'ghaziabad', 'faridabad'],
  'kolkata': ['calcutta'],
  'chennai': ['madras'],
  'pune': ['poona'],
  'new_york': ['nyc', 'new jersey', 'nj', 'manhattan', 'brooklyn', 'jersey city'],
  'bay_area': ['sf', 'san francisco', 'san jose', 'silicon valley', 'oakland', 'palo alto'],
  'washington_dc': ['dc', 'virginia', 'maryland'],
  'los_angeles': ['la'],
  'dallas': ['fort worth', 'irving', 'plano'],
  'toronto': ['gta', 'brampton', 'mississauga'],
  'vancouver': ['surrey', 'burnaby'],
};

/// Other names a country goes by. Lowercase, keyed by the server's key.
const _countryAliases = <String, List<String>>{
  'us': ['usa', 'america', 'united states of america'],
  'gb': ['uk', 'england', 'britain', 'great britain'],
  'ae': ['uae', 'emirates'],
};

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.groups});

  /// (country key, country label, its cities). One group with an empty label
  /// for a server that does not group.
  final List<(String, String, List<PromptOption>)> groups;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';

  bool _matches(String text) => text.toLowerCase().contains(_query);

  /// The groups with only what matches. A country that matches keeps all its
  /// cities, so "uk" lists the four British ones.
  List<(String, List<PromptOption>)> get _shown {
    if (_query.isEmpty) {
      return [for (final (_, label, cities) in widget.groups) (label, cities)];
    }
    return [
      for (final (key, label, cities) in widget.groups)
        if (_matches(label) || (_countryAliases[key] ?? const []).any(_matches))
          (label, cities)
        else if (cities
            .where(
              (c) => _matches(c.label) || (_aliases[c.key] ?? const []).any(_matches),
            )
            .toList() case final found when found.isNotEmpty)
          (label, found),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Where you live', style: AppText.title3),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            textCapitalization: TextCapitalization.words,
            style: AppText.body,
            decoration: InputDecoration(
              hintText: 'Search a city or a country',
              hintStyle: AppText.body.copyWith(color: AppColors.label4),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.label3),
              filled: true,
              fillColor: AppColors.canvas,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.row),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Half the screen at most, as the other list sheets: one that grows
          // past the top edge cannot be dismissed.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Not open there yet. Pick the city you live nearest to.',
                      style: AppText.caption,
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (country, cities) in shown) ...[
                        if (country.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 14, 2, 4),
                            child: Text(country, style: AppText.footnote),
                          ),
                        for (final city in cities)
                          Pressable(
                            onTap: () {
                              final picked = City.parse(city.key);
                              if (picked != City.unknown) {
                                Navigator.of(context).pop(picked);
                              }
                            },
                            child: Container(
                              height: 46,
                              alignment: Alignment.centerLeft,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.separator,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Text(city.label, style: AppText.body),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
