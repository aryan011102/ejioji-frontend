import 'package:flutter/widgets.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/identity.dart';
import '../../../../shared/widgets/pressable.dart';

/// The other person's photo at the top of a chat, ringed when there are in
/// common stories behind it: coloured until they are seen, grey after, and
/// turning while they load.
class StoryRing extends StatefulWidget {
  const StoryRing({
    required this.name,
    required this.onTap,
    this.ringed = true,
    this.opposites = false,
    this.imageUrl,
    this.seen = false,
    this.loading = false,
    this.size = 32,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final bool seen;
  final bool loading;
  final double size;
  final VoidCallback onTap;

  /// False draws the photo alone, in the same space, and it does not take a
  /// tap: nothing in common yet, or the read has not answered.
  final bool ringed;

  /// The ring opens an opposites deck: where the two differ (2026-10-12).
  final bool opposites;

  @override
  State<StoryRing> createState() => _StoryRingState();
}

class _StoryRingState extends State<StoryRing> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StoryRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.loading && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.loading && _spin.isAnimating) {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.size + 7;
    // The same space with or without the ring, so the title does not shift
    // when it arrives. The photo built again then joins the same image load,
    // finished or not, so it does not blink.
    final face = SizedBox.square(
      dimension: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.ringed) ...[
            RotationTransition(
              turns: _spin,
              child: Container(
                width: outer,
                height: outer,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.seen ? null : AppColors.storyRing,
                  color: widget.seen ? AppColors.label4 : null,
                ),
              ),
            ),
            Container(
              width: widget.size + 3,
              height: widget.size + 3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.group,
              ),
            ),
          ],
          Avatar(
            seedColor: AppColors.fill,
            size: widget.size,
            imageUrl: widget.imageUrl,
          ),
        ],
      ),
    );
    if (!widget.ringed) return face;
    return Pressable(
      onTap: widget.onTap,
      semanticLabel: widget.opposites
          ? 'See where you and ${widget.name} differ'
          : 'See what you and ${widget.name} have in common',
      child: face,
    );
  }
}
