import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/entry.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';

/// The only part of a profile filled in by hand.
///
/// Everything asked here becomes both a pill on the profile and a filter other
/// people can use — a filter for something never collected returns nothing.
class CreateProfilePage extends ConsumerStatefulWidget {
  const CreateProfilePage({super.key});

  @override
  ConsumerState<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends ConsumerState<CreateProfilePage> {
  final _photos = <Color?>[Demo.meSeed, null, null];

  final _fields = <String, String>{
    'Name': Demo.meName,
    'Date of birth': '14 March 1998',
    'Gender': 'Woman',
    'City': 'Bengaluru',
    'Work': 'Product designer',
    'Education': "Master's, NID",
    'Languages': 'Hindi, English +1',
  };

  int get _photoCount => _photos.whereType<Color>().length;
  bool get _ready => _photoCount > 0;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: const AppNavBar(),
      footer: PrimaryButton(
        label: 'Continue',
        onPressed: _ready ? () => context.push(Routes.connect) : null,
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const LargeTitle(
            'The basics',
            subtitle: 'This is the only part you fill in by hand. The rest '
                'comes from what you already did.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Photos · $_photoCount of 3',
                    style: AppText.footnote,
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _photos.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: PhotoSlot(
                          filledColor: _photos[i],
                          main: i == 0,
                          label: i == 0 ? 'Main' : 'Add',
                          // TODO(backend): open the OS picker, upload to the
                          // media service, and store the returned id. The file
                          // is never sent to our own API directly.
                          onTap: () => setState(
                            () => _photos[i] ??= Demo.photos[i],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Your first photo is the one people see first. Clear face, '
                    'no group shots.',
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionGroup(
            header: 'About you',
            children: [
              for (final key in ['Name', 'Date of birth', 'Gender'])
                FieldRow(
                  label: key,
                  value: _fields[key],
                  last: key == 'Gender',
                  onTap: () {},
                ),
            ],
          ),
          SectionGroup(
            header: 'Where and what',
            footer: 'Each of these becomes a pill on your profile, and a '
                'filter other people can use.',
            children: [
              for (final key in ['City', 'Work', 'Education', 'Languages'])
                FieldRow(
                  label: key,
                  value: _fields[key],
                  last: key == 'Languages',
                  onTap: () {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}
