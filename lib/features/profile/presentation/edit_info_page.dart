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

/// The same fields again, revisited rather than filled in.
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
  String? _lastName;
  DateTime? _birthDate;
  Gender? _gender;
  City? _city;
  final _languages = <Language>{};
  Education? _education;

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
      // The fields go together: the server takes them as one profile, so there
      // is no such thing as a partial save here. That is also why every one of
      // them has to be sent, including the optional ones: leaving a field out
      // of this call is how you quietly erase it.
      await ref.read(profileRepositoryProvider).save(
            firstName: _name!,
            lastName: (_lastName ?? '').trim().isEmpty ? null : _lastName,
            birthDate: _birthDate!,
            gender: _gender!,
            city: _city!,
            languages: [
              for (final l in Language.values)
                if (_languages.contains(l)) l,
            ],
            education: _education,
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

  Future<void> _editLastName() async {
    final typed = await showTextEntrySheet(
      context,
      title: 'Last name',
      hint: 'Optional',
      initial: _lastName ?? '',
      maxLength: 40,
    );
    if (typed != null) {
      setState(() {
        _lastName = typed;
        _dirty = true;
      });
    }
  }

  Future<void> _pickLanguages() async {
    final offered =
        ref.read(profileOptionsProvider).valueOrNull?.languages ?? [];
    if (offered.isEmpty) return;
    final chosen = await showMultiChoiceSheet(
      context,
      title: 'Languages',
      subtitle: 'Select every language you speak comfortably.',
      options: [for (final o in offered) (o.key, o.label)],
      initial: {for (final l in _languages) l.wire},
    );
    if (chosen == null) return;
    setState(() {
      _languages
        ..clear()
        ..addAll([
          for (final o in offered)
            if (chosen.contains(o.key))
              if (Language.parse(o.key) case final l?) l,
        ]);
      _dirty = true;
    });
  }

  Future<void> _pickEducation() async {
    final offered =
        ref.read(profileOptionsProvider).valueOrNull?.educations ?? [];
    if (offered.isEmpty) return;
    final choice = await showAppActionSheet(
      context,
      title: 'Education',
      actions: [for (final e in offered) SheetAction(e.label)],
    );
    if (choice != null) {
      setState(() {
        _education = Education.parse(offered[choice].key);
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
      _lastName = details.lastName;
      _birthDate = details.birthDate;
      _gender = details.gender;
      _city = details.city;
      _languages.addAll(details.languages);
      _education = details.education;
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
                          child: DraggablePhotoSlot(
                            index: i,
                            filled: i < photos.assets.length,
                            onMove: (from, to) => ref
                                .read(photoPoolProvider.notifier)
                                .movePhoto(from, to, onError: _toast),
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
                        ),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      'Your first photo is the one people see first. Hold '
                      'one and drag it to change the order. Photos save as '
                      'soon as you add them.',
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
                  label: 'Last name',
                  value: (_lastName ?? '').isEmpty ? null : _lastName,
                  placeholder: 'Optional',
                  onTap: _editLastName,
                ),
                FieldRow(
                  label: 'Date of birth',
                  value: _birthDate == null ? null : _formatDate(_birthDate!),
                  onTap: _pickDate,
                ),
                FieldRow(
                  label: 'Gender',
                  value: _gender?.label,
                  last: true,
                  onTap: _pickGender,
                ),
              ],
            ),
            SectionGroup(
              header: 'Background',
              footer: 'Both are optional, and both narrow who you see and who '
                  'sees you once you set a filter on them.',
              children: [
                FieldRow(
                  label: 'Languages',
                  value: _languages.isEmpty ? null : _languageSummary,
                  placeholder: 'Optional',
                  onTap: _pickLanguages,
                ),
                FieldRow(
                  label: 'Education',
                  value: _education?.label,
                  placeholder: 'Optional',
                  last: true,
                  onTap: _pickEducation,
                ),
              ],
            ),
            SectionGroup(
              header: 'Location',
              children: [
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

  /// Two names, then a count: twelve labels would not fit the row.
  String get _languageSummary {
    final chosen = [
      for (final l in Language.values)
        if (_languages.contains(l)) l.label,
    ];
    if (chosen.length <= 2) return chosen.join(', ');
    return '${chosen.take(2).join(', ')} +${chosen.length - 2}';
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
