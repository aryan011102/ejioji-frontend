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
    return Pressable(
      onTap: widget.onTap,
      semanticLabel: 'See what you and ${widget.name} have in common',
      child: SizedBox.square(
        dimension: outer,
        child: Stack(
          alignment: Alignment.center,
          children: [
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
            Avatar(
              seedColor: AppColors.fill,
              size: widget.size,
              imageUrl: widget.imageUrl,
            ),
          ],
        ),
      ),
    );
  }
}
