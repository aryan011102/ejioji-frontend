import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../data/verification_repository.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/steps.dart';
import 'verify_result_page.dart';

/// The selfie check: one photo from the front camera, compared with every
/// photo on the profile that has a face in it.
///
/// Said before the camera opens, because nothing about a face check should be
/// a surprise while the camera is already on your face. There is no pose and
/// no gallery step: the server checks the selfie against the photos people
/// actually see, and that is the whole promise of the tick (Aryan,
/// 2026-10-27).
class SelfiePage extends ConsumerStatefulWidget {
  const SelfiePage({super.key});

  @override
  ConsumerState<SelfiePage> createState() => _SelfiePageState();
}

class _SelfiePageState extends ConsumerState<SelfiePage> {
  final _picker = ImagePicker();
  bool _checking = false;

  /// The server refuses a selfie without an open selfie_verification grant.
  /// Taking the selfie is the person choosing to verify this way, so it is
  /// granted then, as DigiLocker's is (Aryan, 2026-09-30).
  Future<void> _take() async {
    final XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        // The server re-encodes to 1600px on the long side; nothing larger
        // helps the comparison.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
    } on Exception {
      if (mounted) {
        showAppToast(
          context,
          'The camera could not open. Allow it in Settings and try again.',
        );
      }
      return;
    }
    if (shot == null || !mounted) return;

    setState(() => _checking = true);
    try {
      await ref
          .read(consentRepositoryProvider)
          .grantNow(ConsentPurpose.selfieVerification);
      ref.invalidate(consentProvider);
      final result = await ref
          .read(verificationRepositoryProvider)
          .checkSelfie(await shot.readAsBytes());
      ref
        ..invalidate(verificationProvider)
        ..invalidate(myProfileProvider);
      if (!mounted) return;
      if (result.verified) {
        context.pushReplacement(Routes.selfieDone, extra: result.tier);
        return;
      }
      context.pushReplacement(
        Routes.verifyFailed,
        extra: VerifyFailure(
          route: VerifyRoute.selfie,
          title: _title(result),
          body: result.message,
          fixable: result.aboutPhotos,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _title(SelfieResult result) => switch (result.outcome) {
        'photos_differ' => 'Some photos are not you.',
        'no_face_in_photos' || 'no_photos' => 'No photo shows your face.',
        _ => 'Try that selfie again.',
      };

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Selfie check',
        backLabel: 'Verify',
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: _checking ? 'Checking' : 'Take the selfie',
        busy: _checking,
        icon: const Icon(
          Icons.photo_camera_front_outlined,
          size: 18,
          color: AppColors.onAccent,
        ),
        onPressed: _checking ? null : _take,
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
            'One selfie, a few seconds.',
            style: AppText.title1.copyWith(fontSize: 27, height: 33 / 27),
          ),
          const SizedBox(height: 8),
          Text(
            'We check that the face in it is the face in your profile '
            'photos, then throw the selfie away.',
            style: AppText.callout,
          ),
          const SizedBox(height: 26),
          const StepRow(
            number: '1',
            title: 'Take the selfie',
            body: 'Front camera, good light, just you, nothing covering your '
                'face.',
          ),
          const StepRow(
            number: '2',
            title: 'We compare it with your photos',
            body: 'Every photo of you on your profile has to be you. Group '
                'photos are fine, and photos with no face in them are left '
                'alone.',
            last: true,
          ),
          const SizedBox(height: 26),
          const NoteCard(
            icon: Icons.lock_outline,
            text: 'Nobody ever sees the selfie. It is compared by Amazon '
                'Rekognition in India and not kept by anyone. Add or swap a '
                'photo later and you will be asked for a new one.',
          ),
        ],
      ),
    );
  }
}
