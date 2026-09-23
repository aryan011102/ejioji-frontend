import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/models/social.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/social_mark.dart';

/// Adding or changing one social link: a username or a pasted profile link,
/// whichever the person has to hand.
///
/// Nothing is read from the network. The server keeps the handle alone and
/// builds the link a match opens from it, so whatever was pasted (a share link
/// with its tracking query, a mobile address, twitter.com) never reaches
/// anyone. Its refusals say what was wrong ("That link is for X"), so they are
/// shown under the field rather than as a toast that is gone before it is read.
///
/// Returns true when something changed.
Future<bool> showSocialLinkSheet(
  BuildContext context, {
  required SocialNetwork network,
  SocialLink? existing,
}) async {
  final changed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SocialLinkSheet(network: network, existing: existing),
    ),
  );
  return changed ?? false;
}

class _SocialLinkSheet extends ConsumerStatefulWidget {
  const _SocialLinkSheet({required this.network, this.existing});

  final SocialNetwork network;
  final SocialLink? existing;

  @override
  ConsumerState<_SocialLinkSheet> createState() => _SocialLinkSheetState();
}

class _SocialLinkSheetState extends ConsumerState<_SocialLinkSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.existing?.handle ?? '');
  late bool _shown = widget.existing?.shown ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _label => widget.network.label;

  bool get _dirty =>
      _text.text.trim().isNotEmpty &&
      (_text.text.trim() != widget.existing?.handle ||
          _shown != (widget.existing?.shown ?? true));

  String get _hint => switch (widget.network) {
        SocialNetwork.linkedin => 'your-name or linkedin.com/in/your-name',
        _ => '@username or your profile link',
      };

  Future<void> _done() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(profileRepositoryProvider);
    try {
      var link = await repo.saveSocial(widget.network, _text.text.trim());
      if (link.shown != _shown) {
        link = await repo.setSocialShown(widget.network, _shown);
      }
      ref.invalidate(mySocialsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final choice = await showAppActionSheet(
      context,
      title: 'Remove your $_label?',
      message: 'Your matches stop seeing it straight away.',
      actions: const [SheetAction('Remove', destructive: true)],
    );
    if (choice != 0 || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).deleteSocial(widget.network);
      ref.invalidate(mySocialsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(Radii.row)),
      borderSide: BorderSide.none,
    );
    return AppScaffold(
      navBar: AppNavBar(
        leadingLabel: 'Cancel',
        onLeading: () => Navigator.of(context).pop(false),
        trailingLabel: 'Done',
        trailingEnabled: _dirty && !_saving,
        onTrailing: _done,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.titleGutter,
          6,
          Insets.titleGutter,
          24,
        ),
        children: [
          Row(
            children: [
              SocialMark(widget.network, size: 34),
              const SizedBox(width: 12),
              Text(_label, style: AppText.title1.copyWith(fontSize: 24)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Only people you match with see this, as a link to your '
            '$_label. It is never on your profile card or in anyone\'s feed.',
            style: AppText.callout.copyWith(height: 20 / 15),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _text,
            autofocus: widget.existing == null,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _dirty ? _done() : null,
            style: AppText.body.copyWith(fontSize: 16),
            cursorColor: AppColors.accent,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              hintText: _hint,
              hintStyle:
                  AppText.body.copyWith(fontSize: 16, color: AppColors.label3),
              filled: true,
              fillColor: AppColors.row,
              contentPadding: const EdgeInsets.all(14),
              border: border,
              enabledBorder: border,
              focusedBorder: border,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              _error ?? 'Type your username, or paste the link to your profile.',
              style: AppText.caption.copyWith(
                height: 16 / 12,
                color: _error == null ? AppColors.label3 : AppColors.destructive,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.row,
              borderRadius: BorderRadius.circular(Radii.row),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Show to matches', style: AppText.body),
                      const SizedBox(height: 2),
                      Text(
                        _shown
                            ? 'Your matches can open it'
                            : 'Saved, and shown to nobody',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                AppSwitch(
                  value: _shown,
                  onChanged: _saving ? null : (v) => setState(() => _shown = v),
                ),
              ],
            ),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: _saving ? null : _remove,
                child: Text(
                  'Remove $_label',
                  style: AppText.body.copyWith(color: AppColors.destructive),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
