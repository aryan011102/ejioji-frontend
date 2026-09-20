import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/photo_controller.dart';
import '../../../data/providers.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/entry.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';

/// The only part of a profile filled in by hand, and it is four fields.
///
/// The original form asked for work, education, languages and a bio as well.
/// Those are gone, and their absence is the point: if people describe
/// themselves first they write a conventional matrimonial profile, and the
/// derived tiles then have to argue with it. We ask less precisely because we
/// promise more.
///
/// A last name is asked for from 2026-09-20 and is optional. It was left out
/// until then because a surname next to purchase history is how caste gets
/// inferred, and this product holds the purchase history; the backend decision
/// log for that date carries the reversal. It is shown to nobody in the feed:
/// a card carries a first name and a city.
///
/// Languages and education are optional too, and both are filters as well as
/// facts, so leaving them blank is what keeps them out of matching entirely.
class CreateProfilePage extends ConsumerStatefulWidget {
  const CreateProfilePage({super.key});

  @override
  ConsumerState<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends ConsumerState<CreateProfilePage> {
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  DateTime? _birthDate;
  Gender? _gender;
  City? _city;
  final _languages = <Language>{};
  Education? _education;
  bool _saving = false;
  bool _seeded = false;

  /// Two photos to publish; the form asks for three so nobody arrives at the
  /// gate one short.
  static const _slots = 3;

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    super.dispose();
  }

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      _birthDate != null &&
      _gender != null &&
      _city != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Eighteen is the floor the server enforces. Opening the picker on the
    // latest allowed date rather than today saves a decade of scrolling.
    final latest = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 27, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: latest,
      helpText: 'Your date of birth',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickLanguages() async {
    final options = ref.read(profileOptionsProvider).valueOrNull;
    final offered = options?.languages ?? const [];
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
    });
  }

  Future<void> _pickEducation() async {
    final options = ref.read(profileOptionsProvider).valueOrNull;
    final offered = options?.educations ?? const [];
    if (offered.isEmpty) return;

    final choice = await showAppActionSheet(
      context,
      title: 'Education',
      actions: [for (final e in offered) SheetAction(e.label)],
    );
    if (choice != null) {
      setState(() => _education = Education.parse(offered[choice].key));
    }
  }

  Future<void> _pickGender() async {
    final choice = await showAppActionSheet(
      context,
      title: 'Gender',
      actions: [for (final g in Gender.values) SheetAction(g.label)],
    );
    if (choice != null) setState(() => _gender = Gender.values[choice]);
  }

  Future<void> _pickCity() async {
    // The list comes from the server, so adding a city does not need an app
    // release. We launch one city at a time and the others are there for when
    // that changes.
    final options = ref.read(profileOptionsProvider).valueOrNull;
    final cities = options?.cities ?? const [];
    if (cities.isEmpty) return;

    final choice = await showAppActionSheet(
      context,
      title: 'Where you live',
      actions: [for (final c in cities) SheetAction(c.label)],
    );
    if (choice != null) {
      setState(() => _city = City.parse(cities[choice].key));
    }
  }

  Future<void> _save() async {
    if (!_ready || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).save(
            firstName: _name.text.trim(),
            lastName: _lastName.text.trim().isEmpty
                ? null
                : _lastName.text.trim(),
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
      context.push(Routes.connect);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(photoPoolProvider);
    final mine = ref.watch(myProfileProvider);

    // Somebody who got halfway and came back should find their answers, not a
    // blank form.
    final existing = mine.valueOrNull?.profile;
    if (!_seeded && existing != null) {
      _seeded = true;
      _name.text = existing.firstName;
      _lastName.text = existing.lastName ?? '';
      _birthDate = existing.birthDate;
      _gender = existing.gender;
      _city = existing.city;
      _languages.addAll(existing.languages);
      _education = existing.education;
    }

    return AppScaffold(
      navBar: const AppNavBar(),
      footer: PrimaryButton(
        label: 'Continue',
        busy: _saving,
        onPressed: _ready ? _save : null,
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
                    'Photos · ${photos.assets.length} of $_slots',
                    style: AppText.footnote,
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
                          busy: photos.uploading && i == photos.assets.length,
                          main: i == 0,
                          label: i == 0 ? 'Main' : 'Add',
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
                    'Your first photo is the one people see first. Clear face, '
                    'no group shots. Two are needed to publish.',
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionGroup(
            header: 'About you',
            footer: 'Your age is shown, your date of birth is not. A last name '
                'is optional and is never used to match you with anyone.',
            children: [
              FieldRow(
                label: 'First name',
                value: _name.text.isEmpty ? null : _name.text,
                onTap: _editName,
              ),
              FieldRow(
                label: 'Last name',
                value: _lastName.text.isEmpty ? null : _lastName.text,
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
            footer: 'Both are optional. Left blank, neither is used to narrow '
                'who you see or who sees you.',
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
    );
  }

  void _toast(String message) {
    if (mounted) showAppToast(context, message);
  }

  Future<void> _photoSheet(String mediaId) async {
    final choice = await showAppActionSheet(
      context,
      actions: const [SheetAction('Remove photo', destructive: true)],
    );
    if (choice == 0) {
      await ref
          .read(photoPoolProvider.notifier)
          .remove(mediaId, onError: _toast);
    }
  }

  /// Two names, then a count. Twelve labels in a row would not fit the row.
  String get _languageSummary {
    final chosen = [
      for (final l in Language.values)
        if (_languages.contains(l)) l.label,
    ];
    if (chosen.length <= 2) return chosen.join(', ');
    return '${chosen.take(2).join(', ')} +${chosen.length - 2}';
  }

  Future<void> _editLastName() async {
    final typed = await showTextEntrySheet(
      context,
      title: 'Last name',
      hint: 'Optional',
      initial: _lastName.text,
      maxLength: 40,
    );
    if (typed != null) setState(() => _lastName.text = typed);
  }

  Future<void> _editName() async {
    final typed = await showTextEntrySheet(
      context,
      title: 'First name',
      hint: 'What people call you',
      initial: _name.text,
      maxLength: 40,
    );
    if (typed != null) setState(() => _name.text = typed);
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
