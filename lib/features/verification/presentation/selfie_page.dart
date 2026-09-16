import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';

/// The three steps, said before the camera opens.
///
/// Nothing about a liveness check should be a surprise while the camera is
/// already on your face.
class SelfieStepsPage extends ConsumerWidget {
  const SelfieStepsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Selfie check',
        backLabel: 'Verify',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: 'Start',
        onPressed: () => context.push(Routes.selfieStepAt(1)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.titleGutter,
          22,
          Insets.titleGutter,
          40,
        ),
        children: [
          const IconPlate(
            Icons.face_retouching_natural_outlined,
            size: 52,
            radius: 16,
            background: AppColors.blueSoft,
            foreground: AppColors.blue,
          ),
          const SizedBox(height: 16),
          Text(
            'Three steps, two minutes.',
            style: AppText.title1.copyWith(fontSize: 27, height: 33 / 27),
          ),
          const SizedBox(height: 8),
          Text(
            'Nobody ever sees any of this. It is checked against your profile '
            'photos and deleted.',
            style: AppText.callout,
          ),
          const SizedBox(height: 26),
          const StepRow(
            number: '1',
            title: 'Copy a pose',
            body: "We'll show one on screen — a hand raised, or a head turned. "
                'It changes every time, which is what makes a photograph of a '
                'photograph fail.',
          ),
          const StepRow(
            number: '2',
            title: 'Take the selfie',
            body: 'Front camera, good light, nothing covering your face.',
          ),
          const StepRow(
            number: '3',
            title: 'Add one photo from your gallery',
            body: 'Any photo of you that already exists. Two sources are '
                'harder to fake than one.',
            last: true,
          ),
          const SizedBox(height: 26),
          const NoteCard(
            icon: Icons.lock_outline,
            text: 'The selfie is never shown to another person and is deleted '
                'once the check is done.',
          ),
        ],
      ),
    );
  }
}

/// One shell for all three steps: a view, guidance, a caption and one control.
///
/// The pose is generated per attempt, which is the entire liveness argument —
/// a photograph of a photograph cannot raise its hand on request.
class SelfieCapturePage extends ConsumerWidget {
  const SelfieCapturePage({required this.step, super.key});

  final int step;

  static const _captions = <int, (String, String)>{
    1: (
      'Copy this pose',
      'Right hand up, beside your face. Hold it until the ring closes.',
    ),
    2: ('Now take the selfie', 'Face the camera, no hat, no sunglasses.'),
    3: (
      'One photo from your gallery',
      'Any photo of you that already exists on this phone.',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, body) = _captions[step] ?? _captions[1]!;
    final gallery = step == 3;

    void next() {
      if (step < 3) {
        context.pushReplacement(Routes.selfieStepAt(step + 1));
      } else {
        // TODO(backend): POST Api.selfieSubmit with the two captures. They are
        // uploaded directly to the media service over TLS and are never
        // written to disk unencrypted.
        context.pushReplacement(Routes.selfieDone);
      }
    }

    return AppScaffold(
      navBar: AppNavBar(
        title: 'Step $step of 3',
        backLabel: 'Back',
        onBack: () => context.pop(),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              0,
              Insets.gutter,
              14,
            ),
            child: AppProgressBar(value: step / 3),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              child: gallery
                  ? _GalleryWell(title: title, body: body, onPick: next)
                  : _CameraView(step: step, title: title, body: body),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
            child: gallery
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: PrimaryButton(
                      label: 'Choose from gallery',
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        size: 18,
                        color: AppColors.onAccent,
                      ),
                      onPressed: next,
                    ),
                  )
                : Pressable(
                    onTap: next,
                    semanticLabel: 'Take photo',
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: AppColors.row,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.label, width: 4),
                      ),
                      child: const Icon(
                        Icons.photo_camera,
                        size: 26,
                        color: AppColors.label2,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CameraView extends StatelessWidget {
  const _CameraView({
    required this.step,
    required this.title,
    required this.body,
  });

  final int step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // TODO(backend): the live front-camera preview goes here. Frames are
          // never written to disk and never leave the device except as the one
          // capture the person confirms.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A3F44), Color(0xFF1A1418)],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 196,
              height: 262,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(130),
                border: Border.all(color: const Color(0x80FFFFFF), width: 3),
              ),
            ),
          ),
          if (step == 1)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 86,
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0x80000000),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.back_hand_outlined,
                      size: 34,
                      color: AppColors.label,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Copy this',
                      style: AppText.micro.copyWith(
                        fontSize: 10,
                        color: const Color(0xB3FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB8000000)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.title3),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: AppText.footnote.copyWith(
                      fontSize: 13.5,
                      color: const Color(0xC7FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One well, not a grid.
///
/// A nine-up gallery grid reads as nine things to add, and this step asks for
/// one — so it uses the same 3:4 slot Create profile does, and the gesture is
/// already learned.
class _GalleryWell extends StatelessWidget {
  const _GalleryWell({
    required this.title,
    required this.body,
    required this.onPick,
  });

  final String title;
  final String body;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.row,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 206,
            child: PhotoSlot(label: 'Add a photo', onTap: onPick),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: AppText.title3),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppText.footnote.copyWith(fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
