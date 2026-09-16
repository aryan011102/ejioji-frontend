import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/photo_controller.dart';
import '../../../data/providers.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/entry.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

/// The four fields again, revisited rather than filled in.
///
/// Two things change from setup: Continue becomes Save, and leaving half-done
/// is allowed. Save is grey until something changes, because a Save that is
/// always live teaches people to press it for nothing and then to ignore it.
///
/// Photos save immediately, and deliberately do not wait for Save: an upload
/// has already happened by the time it appears, and a photo that vanished
/// because somebody backed out of a screen would be alarming.
class EditInfoPage extends ConsumerStatefulWidget {
  const EditInfoPage({super.key});

  @override
  ConsumerState<EditInfoPage> createState() => _EditInfoPageState();
}

class _EditInfoPageState extends ConsumerState<EditInfoPage> {
  static const _slots = 3;

  String? _name;
  DateTime? _birthDate;
  Gender? _gender;
  City? _city;

  bool _dirty = false;
  bool _saving = false;
  bool _seeded = false;

  void _toast(String message) {
    if (mounted) showAppToast(context, message);
  }

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

  Future<void> _save() async {
    if (!_dirty || _saving) return;
    if (_name == null ||
        _birthDate == null ||
        _gender == null ||
        _city == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      // The four fields go together: the server takes them as one profile, so
      // there is no such thing as a partial save here.
      await ref.read(profileRepositoryProvider).save(
            firstName: _name!,
            birthDate: _birthDate!,
            gender: _gender!,
            city: _city!,
          );
      final profile = await ref.read(profileRepositoryProvider).load();
      if (!mounted) return;
      ref.read(sessionProvider.notifier).onProfileChanged(profile);
      ref.invalidate(myProfileProvider);
      setState(() => _dirty = false);
      showAppToast(context, 'Saved.');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editName() async {
    final typed = await showTextEntrySheet(
      context,
      title: 'First name',
      hint: 'What people call you',
      initial: _name ?? '',
      maxLength: 40,
    );
    if (typed != null) {
      setState(() {
        _name = typed;
        _dirty = true;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 27),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Your date of birth',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _dirty = true;
      });
    }
  }

  Future<void> _pickGender() async {
    final choice = await showAppActionSheet(
      context,
      title: 'Gender',
      actions: [for (final g in Gender.values) SheetAction(g.label)],
    );
    if (choice != null) {
      setState(() {
        _gender = Gender.values[choice];
        _dirty = true;
      });
    }
  }

  Future<void> _pickCity() async {
    final cities = ref.read(profileOptionsProvider).valueOrNull?.cities ?? [];
    if (cities.isEmpty) return;
    final choice = await showAppActionSheet(
      context,
      title: 'Where you live',
      actions: [for (final c in cities) SheetAction(c.label)],
    );
    if (choice != null) {
      setState(() {
        _city = City.parse(cities[choice].key);
        _dirty = true;
      });
    }
  }

  Future<void> _photoSheet(String mediaId) async {
    final choice = await showAppActionSheet(
      context,
      message: 'Removing a photo can take your profile below the two it needs '
          'to show, and it will stop showing until you add another.',
      actions: const [SheetAction('Remove photo', destructive: true)],
    );
    if (choice == 0) {
      await ref
          .read(photoPoolProvider.notifier)
          .remove(mediaId, onError: _toast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myProfileProvider);
    final photos = ref.watch(photoPoolProvider);

    final details = mine.valueOrNull?.profile;
    if (!_seeded && details != null) {
      _seeded = true;
      _name = details.firstName;
      _birthDate = details.birthDate;
      _gender = details.gender;
      _city = details.city;
    }

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Your info',
        backLabel: 'Profile',
        onBack: _leave,
        trailingLabel: 'Save',
        trailingEnabled: _dirty && !_saving,
        onTrailing: _save,
      ),
      child: mine.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (_) => ListView(
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
                      'PHOTOS · ${photos.assets.length} OF $_slots',
                      style: AppText.groupHeader,
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _slots; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: PhotoSlot(
                            imageUrl: i < photos.assets.length
                                ? photos.assets[i].stillUrl
                                : null,
                            busy: photos.uploading &&
                                i == photos.assets.length,
                            main: i == 0,
                            onTap: () => i < photos.assets.length
                                ? _photoSheet(photos.assets[i].id)
                                : ref
                                    .read(photoPoolProvider.notifier)
                                    .add(onError: _toast),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      'Your first photo is the one people see first. Photos '
                      'save as soon as you add them.',
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            ),
            SectionGroup(
              header: 'About you',
              footer: 'Your age is shown, your date of birth is not.',
              children: [
                FieldRow(
                  label: 'First name',
                  value: _name,
                  onTap: _editName,
                ),
                FieldRow(
                  label: 'Date of birth',
                  value: _birthDate == null ? null : _formatDate(_birthDate!),
                  onTap: _pickDate,
                ),
                FieldRow(
                  label: 'Gender',
                  value: _gender?.label,
                  onTap: _pickGender,
                ),
                FieldRow(
                  label: 'City',
                  value: _city == null || _city == City.unknown
                      ? null
                      : _city!.label,
                  last: true,
                  onTap: _pickCity,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
