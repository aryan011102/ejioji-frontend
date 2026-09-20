import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'pressable.dart';

/// Which check passed.
///
/// Blue is one — either a government ID or a live selfie. Gold is both. The
/// shape never changes, only the fill: a tick that changes shape reads as a
/// different promise, and this one is the same promise twice over.
enum VerificationTier { none, blue, gold }

class VerifiedTick extends StatelessWidget {
  const VerifiedTick({
    required this.tier,
    this.size = 20,
    this.onTap,
    super.key,
  });

  final VerificationTier tier;
  final double size;

  /// Only your own outline tick is tappable. A viewer tapping someone else's
  /// tick should get nothing, because there is nothing for them to do.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unverified = tier == VerificationTier.none;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (tier) {
          VerificationTier.none => const Color(0x00000000),
          VerificationTier.blue => AppColors.blue,
          VerificationTier.gold => AppColors.gold,
        },
        border: unverified ? Border.all(color: AppColors.label4, width: 1.6) : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.check,
        size: size * 0.62,
        color: unverified ? AppColors.label4 : AppColors.onAccent,
      ),
    );

    if (onTap == null) {
      return Semantics(
        label: switch (tier) {
          VerificationTier.gold => 'Verified with an ID and a photo',
          VerificationTier.blue => 'Verified',
          VerificationTier.none => 'Not verified',
        },
        child: mark,
      );
    }
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Verify your profile',
      child: mark,
    );
  }
}

/// A person, before their photo has loaded or where a photo is not the point.
///
/// [blurred] is the free state of Profile views — it is a real state, not a
/// placeholder, which is why the blur lives here rather than in that screen.
class Avatar extends StatelessWidget {
  const Avatar({
    required this.seedColor,
    this.size = 46,
    this.imageUrl,
    this.blurred = false,
    super.key,
  });

  final Color seedColor;
  final double size;
  final String? imageUrl;
  final bool blurred;

  @override
  Widget build(BuildContext context) {
    // The URL is signed and expires, so it is only ever held in the in-memory
    // image cache. Nothing here writes a photo to disk: a cached face outliving
    // the account it belongs to is the kind of thing erasure cannot reach.
    final url = imageUrl;

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairline),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [seedColor, const Color(0x8C000000)],
        ),
      ),
      clipBehavior: url == null ? Clip.none : Clip.antiAlias,
      child: url == null
          ? null
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // A signature that has expired, or a photo taken down between
              // the read and the render. Falling back to the plain circle is
              // quieter than Flutter's broken-image icon, which on a person
              // reads as something being wrong with them.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
    );

    if (!blurred) return circle;
    return ClipOval(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: circle,
      ),
    );
  }
}

/// A rectangular photo, used for the 3:4 slots and the family page portrait.
class PhotoFrame extends StatelessWidget {
  const PhotoFrame({
    required this.seedColor,
    this.width,
    this.height,
    this.radius = 12,
    this.aspect = 3 / 4,
    this.imageUrl,
    super.key,
  });

  final Color seedColor;
  final double? width;
  final double? height;
  final double radius;
  final double aspect;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.hairline),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [seedColor, const Color(0xC7000000)],
        ),
      ),
    );
    if (width != null || height != null) return box;
    return AspectRatio(aspectRatio: aspect, child: box);
  }
}

/// The empty 3:4 well from Create profile, reused wherever a photo is asked
/// for — editing your info, and the gallery step of the selfie check.
/// A photo slot that can be picked up and dropped on another one.
///
/// This is how the main photo is chosen: the first slot is what people see
/// first, so dragging a photo there makes it the main one. There is no "make
/// this the main photo" menu item, because the order matters past the first
/// slot too and a menu would only speak about one of them.
///
/// A long press starts the drag, so a plain tap still opens the photo's own
/// sheet. An empty slot cannot be dragged, only dropped on.
class DraggablePhotoSlot extends StatelessWidget {
  const DraggablePhotoSlot({
    required this.index,
    required this.filled,
    required this.onMove,
    required this.child,
    super.key,
  });

  final int index;
  final bool filled;
  final void Function(int from, int to) onMove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => onMove(details.data, index),
      builder: (context, candidate, rejected) {
        final over = candidate.isNotEmpty;
        final slot = AnimatedScale(
          scale: over ? 1.04 : 1,
          duration: const Duration(milliseconds: 140),
          child: child,
        );
        if (!filled) return slot;
        return LayoutBuilder(
          builder: (context, constraints) => LongPressDraggable<int>(
            data: index,
            // Sized here because the slot is an Expanded inside a Row, and
            // what is dragged has no parent to take a width from.
            feedback: Opacity(
              opacity: 0.9,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Material(
                  color: const Color(0x00000000),
                  child: child,
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: child),
            child: slot,
          ),
        );
      },
    );
  }
}

class PhotoSlot extends StatelessWidget {
  const PhotoSlot({
    this.imageUrl,
    this.onTap,
    this.label = 'Add',
    this.main = false,
    this.width,
    this.busy = false,
    super.key,
  });

  /// A signed URL for a photo already in the pool. Null means an empty slot.
  final String? imageUrl;

  final VoidCallback? onTap;
  final String label;
  final bool main;
  final double? width;

  /// This slot is where the upload in flight will land.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final filled = imageUrl != null;
    return Pressable(
      onTap: busy ? null : onTap,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          width: width,
          clipBehavior: Clip.antiAlias,
          foregroundDecoration: filled
              ? null
              : const BoxDecoration(color: Color(0x00000000)),
          decoration: BoxDecoration(
            color: AppColors.photoEmpty,
            image: filled
                ? DecorationImage(
                    image: NetworkImage(imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: filled
                ? null
                : Border.all(
                    color: AppColors.photoEdge,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
          ),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.accent,
                  ),
                )
              : filled
              ? (main
                  ? Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x8C000000),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'MAIN',
                          style: AppText.micro.copyWith(
                            color: AppColors.label,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    )
                  : null)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 22, color: AppColors.accent),
                    const SizedBox(height: 6),
                    Text(label, style: AppText.caption.copyWith(fontSize: 11)),
                  ],
                ),
        ),
      ),
    );
  }
}
