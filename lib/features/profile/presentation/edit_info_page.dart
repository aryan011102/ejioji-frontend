import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/entry.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

/// Everything Create profile asked, in the same order, revisited rather than
/// filled in. Two things change: Continue becomes Save, and leaving half-done
/// is allowed.
///
/// Save is grey until something changes. A Save that is always live teaches
/// people to press it for nothing, and then to ignore it.
class EditInfoPage extends ConsumerStatefulWidget {
  const EditInfoPage({super.key});

  @override
  ConsumerState<EditInfoPage> createState() => _EditInfoPageState();
}

class _EditInfoPageState extends ConsumerState<EditInfoPage> {
  bool _dirty = false;

  final _photos = <Color?>[Demo.meSeed, Demo.photos[1], null];

  void _touch() => setState(() => _dirty = true);

  Future<void> _leave() async {
    if (!_dirty) return context.pop();
    final choice = await showAppActionSheet(
      context,
      title: 'Leave without saving?',
      message: 'Your changes to this page will be lost.',
      actions: const [
        SheetAction('Discard changes', destructive: true),
        SheetAction('Keep editing'),
      ],
    );
    if (choice == 0 && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Your info',
        backLabel: 'Profile',
        onBack: _leave,
        trailingLabel: 'Save',
        trailingEnabled: _dirty,
        // TODO(backend): PATCH Api.meProfile with only the changed fields.
        onTrailing: () => setState(() => _dirty = false),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              0,
              Insets.gutter,
              22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
                  child: Text(
                    'PHOTOS · ${_photos.whereType<Color>().length} OF 3',
                    style: AppText.groupHeader,
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
                          onTap: _touch,
                        ),
                      ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Your first photo is the one people see first. Changing it '
                    'does not un-verify you.',
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ),
          SectionGroup(
            header: 'About you',
            children: [
              FieldRow(label: 'Name', value: Demo.meName, onTap: _touch),
              FieldRow(label: 'Pronouns', value: 'she/her', onTap: _touch),
              FieldRow(
                label: 'Date of birth',
                value: '14 March 1998',
                onTap: _touch,
              ),
              FieldRow(
                label: 'Gender',
                value: 'Woman',
                last: true,
                onTap: _touch,
              ),
            ],
          ),
          SectionGroup(
            header: 'Where and what',
            children: [
              FieldRow(label: 'City', value: 'Bengaluru', onTap: _touch),
              FieldRow(
                label: 'Work',
                value: 'Product designer',
                onTap: _touch,
              ),
              FieldRow(label: 'Company', value: 'Zeta', onTap: _touch),
              FieldRow(
                label: 'Education',
                value: "Master's, NID",
                onTap: _touch,
              ),
              FieldRow(
                label: 'Languages',
                value: 'Hindi, English +1',
                last: true,
                onTap: _touch,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
