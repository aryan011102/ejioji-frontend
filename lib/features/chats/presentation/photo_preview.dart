import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/pressable.dart';

/// Shows a photo picked for a chat before it goes, as WhatsApp does. True when
/// they tap send; false or null when they close it, and nothing is uploaded.
Future<bool> confirmPhoto(
  BuildContext context, {
  required Uint8List bytes,
  String? name,
}) async {
  final send = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoPreview(bytes: bytes, name: name),
    ),
  );
  return send ?? false;
}

/// The photo on black, pinch to look closer, a close button and a send button.
/// No caption: a chat photo carries no words on the server.
class PhotoPreview extends StatelessWidget {
  const PhotoPreview({required this.bytes, this.name, super.key});

  final Uint8List bytes;

  /// Who it goes to, shown beside send. Null shows nothing.
  final String? name;

  static const sendKey = ValueKey('photo-preview-send');
  static const closeKey = ValueKey('photo-preview-close');

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    return Scaffold(
      backgroundColor: AppColors.group,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                key: closeKey,
                onTap: () => Navigator.of(context).pop(false),
                semanticLabel: 'Don\'t send',
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.close, color: AppColors.label),
                ),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  if (name != null && name.isNotEmpty)
                    Expanded(
                      child: Text(
                        'To $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.callout.copyWith(color: AppColors.label2),
                      ),
                    )
                  else
                    const Spacer(),
                  Pressable(
                    key: sendKey,
                    onTap: () => Navigator.of(context).pop(true),
                    semanticLabel: 'Send photo',
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.fill,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        size: 22,
                        color: AppColors.onAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
