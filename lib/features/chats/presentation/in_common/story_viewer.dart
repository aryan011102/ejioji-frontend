import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../data/in_common_repository.dart';
import '../../../../shared/models/tile_look.dart';
import '../../../../shared/widgets/identity.dart';
import '../../../../shared/widgets/pressable.dart';

/// Opens the stories over the chat, growing out of the ring.
Future<void> showStories(BuildContext context, InCommon deck) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: Motion.page,
      reverseTransitionDuration: Motion.fade,
      pageBuilder: (_, __, ___) => StoryViewer(deck: deck),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Ease.emphasised);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: const Alignment(0, -0.9),
            scale: Tween<double>(begin: 0.6, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// The in common stories, Wrapped style: a few seconds each, tap the right to
/// go on and the left to go back, hold to pause, and the deck closes after the
/// last one.
class StoryViewer extends StatefulWidget {
  const StoryViewer({required this.deck, super.key});

  final InCommon deck;

  /// How long one story stays before the next.
  static const perStory = Duration(seconds: 6);

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: StoryViewer.perStory)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
  int _index = 0;
  Duration _downAt = Duration.zero;
  final _watch = Stopwatch()..start();

  List<Story> get _stories => widget.deck.stories;

  @override
  void initState() {
    super.initState();
    unawaited(_clock.forward());
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _show(int i) {
    if (i < 0) i = 0;
    if (i >= _stories.length) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index = i);
    _clock
      ..reset()
      ..forward();
  }

  void _next() => _show(_index + 1);
  void _previous() => _show(_index - 1);

  void _hold() {
    _downAt = _watch.elapsed;
    _clock.stop();
  }

  void _release({required bool forward}) {
    final quick = _watch.elapsed - _downAt < const Duration(milliseconds: 250);
    if (quick) {
      HapticFeedback.selectionClick();
      forward ? _next() : _previous();
    } else {
      unawaited(_clock.forward());
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_index];
    final deck = widget.deck;
    return Scaffold(
      backgroundColor: AppColors.group,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: Motion.fade,
            child: _Slide(key: ValueKey(_index), story: story, deck: deck),
          ),
          // Tap zones: a third on the left goes back, the rest goes on.
          Positioned.fill(
            top: 90,
            bottom: 40,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _hold(),
                    onTapUp: (_) => _release(forward: false),
                    onTapCancel: () => unawaited(_clock.forward()),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _hold(),
                    onTapUp: (_) => _release(forward: true),
                    onTapCancel: () => unawaited(_clock.forward()),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  _Bars(count: _stories.length, index: _index, clock: _clock),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Pair(deck: deck, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You & ${deck.them.firstName}',
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong,
                        ),
                      ),
                      Pressable(
                        onTap: () => Navigator.of(context).maybePop(),
                        semanticLabel: 'Close',
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.glass,
                            border: Border.all(color: AppColors.glassEdge),
                          ),
                          child: const Icon(Icons.close, size: 18, color: AppColors.label),
                        ),
                      ),
                    ],
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

class _Bars extends StatelessWidget {
  const _Bars({required this.count, required this.index, required this.clock});

  final int count;
  final int index;
  final Animation<double> clock;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) => Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: i < index ? 1 : (i == index ? clock.value : 0),
                  backgroundColor: AppColors.storyTrack,
                  valueColor: const AlwaysStoppedAnimation(AppColors.label),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Both photos, overlapping: the reader first.
class _Pair extends StatelessWidget {
  const _Pair({required this.deck, required this.size});

  final InCommon deck;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget face(StoryPerson p) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.label, width: size > 60 ? 3 : 1.5),
          ),
          child: Avatar(seedColor: AppColors.fill, size: size, imageUrl: p.photo?.stillUrl),
        );
    return SizedBox(
      width: size * 2 - size * 0.3,
      height: size + 4,
      child: Stack(
        children: [
          face(deck.me),
          Positioned(left: size * 0.7, child: face(deck.them)),
        ],
      ),
    );
  }
}

/// One story. Everything on it rises into place a moment after the last.
class _Slide extends StatelessWidget {
  const _Slide({required this.story, required this.deck, super.key});

  final Story story;
  final InCommon deck;

  LinearGradient get _background {
    final category = story.category;
    if (category != null) return TileTones.of(category.tone);
    return switch (story.kind) {
      StoryKind.thought => TileTones.rose,
      _ => AppColors.promo,
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = deck.them.firstName;
    final children = <Widget>[];
    var step = 0;
    Widget rise(Widget child) => _Rise(delay: Duration(milliseconds: 110 * step++), child: child);

    if (story.kind == StoryKind.intro) {
      children
        ..add(rise(_Pair(deck: deck, size: 104)))
        ..add(const SizedBox(height: 26))
        ..add(rise(_Eyebrow(story.eyebrow)))
        ..add(const SizedBox(height: 12))
        ..add(rise(Text(story.title, style: _Big.intro)))
        ..add(const SizedBox(height: 18));
      if (story.footnote != null) children.add(rise(_Small(story.footnote!)));
      return _Frame(background: _background, center: true, children: children);
    }

    children
      ..add(rise(_Eyebrow(story.eyebrow)))
      ..add(const SizedBox(height: 14))
      ..add(
        rise(
          Text(
            story.title,
            style: story.kind == StoryKind.thought ? _Big.thought : _Big.claim,
          ),
        ),
      );
    final chart = story.chart;
    if (chart != null) {
      children
        ..add(const SizedBox(height: 26))
        ..add(rise(StoryChartView(chart: chart, name: name)));
    }
    children.add(const Spacer());
    if (story.footnote != null) children.add(rise(_Small(story.footnote!)));
    final source = _sourceLine(name);
    if (source != null) {
      children
        ..add(const SizedBox(height: 14))
        ..add(Text(source.toUpperCase(), style: _Small.source));
    }
    return _Frame(background: _background, children: children);
  }

  /// "On your profile · in Meera's insights": where each side's tile lives.
  String? _sourceLine(String name) {
    final me = story.onProfileMe;
    final them = story.onProfileThem;
    if (me == null || them == null) return null;
    if (me && them) return 'On both profiles';
    final mine = me ? 'On your profile' : 'In your insights';
    final theirs = them ? "on $name's profile" : "in $name's insights";
    return '$mine · $theirs';
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.background, required this.children, this.center = false});

  final LinearGradient background;
  final List<Widget> children;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: background),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: Scrims.flat),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 92, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _Big {
  static TextStyle get intro =>
      AppText.tileNumber(54).copyWith(fontWeight: FontWeight.w900, letterSpacing: -2.4);
  static TextStyle get claim =>
      AppText.tileNumber(38).copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.6);
  static TextStyle get thought =>
      AppText.tileNumber(32).copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.1);
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppText.caption.copyWith(
          color: AppColors.label,
          letterSpacing: 2.4,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _Small extends StatelessWidget {
  const _Small(this.text);

  final String text;

  static TextStyle get source =>
      AppText.micro.copyWith(color: AppColors.label2, letterSpacing: 1.2);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.footnote.copyWith(color: AppColors.label));
}

/// Fades and lifts its child into place once, after [delay].
class _Rise extends StatefulWidget {
  const _Rise({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(widget.delay, () {
      if (mounted) unawaited(_c.forward());
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: Ease.emphasised);
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(t),
        child: widget.child,
      ),
    );
  }
}

/// The picture under a story's claim. Every number on it is one the server
/// printed; this only decides where it goes.
class StoryChartView extends StatelessWidget {
  const StoryChartView({required this.chart, required this.name, super.key});

  final StoryChart chart;
  final String name;

  @override
  Widget build(BuildContext context) {
    return switch (chart.type) {
      ChartType.hours => _Strips(
          chart: chart,
          name: name,
          slots: 24,
          labels: const ['12a', '6a', '12p', '6p', '11p'],
        ),
      ChartType.weekdays => _Strips(
          chart: chart,
          name: name,
          slots: 7,
          cellLabels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        ),
      ChartType.months => _Strips(
          chart: chart,
          name: name,
          slots: 12,
          offset: 1,
          cellLabels: const ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'],
        ),
      ChartType.bars => _BarsChart(chart: chart),
      ChartType.numbers => _Numbers(chart: chart),
      ChartType.versus => _Versus(chart: chart),
      ChartType.unknown => const SizedBox.shrink(),
    };
  }
}

/// One row each, a cell per hour, day or month, with each person's own lit.
class _Strips extends StatelessWidget {
  const _Strips({
    required this.chart,
    required this.name,
    required this.slots,
    this.offset = 0,
    this.labels,
    this.cellLabels,
  });

  final StoryChart chart;
  final String name;
  final int slots;
  final int offset;
  final List<String>? labels;
  final List<String>? cellLabels;

  @override
  Widget build(BuildContext context) {
    Widget row(String who, ChartSide side, Color lit) {
      final on = side.value.round() - offset;
      final tall = slots == 24;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              who.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: AppText.micro.copyWith(color: AppColors.label, letterSpacing: 1),
            ),
          ),
          for (var i = 0; i < slots; i++) ...[
            if (i > 0) SizedBox(width: tall ? 2 : 5),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 500 + i * 18),
                curve: Ease.emphasised,
                builder: (context, t, _) => Container(
                  height: tall ? (i == on ? 64 * t : 22) : 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == on ? lit : AppColors.storyDim,
                    borderRadius: BorderRadius.circular(tall ? 3 : 9),
                  ),
                  child: cellLabels == null
                      ? null
                      : Text(
                          cellLabels![i],
                          style: AppText.micro.copyWith(
                            color: i == on ? AppColors.group : AppColors.label2,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('You', chart.me, AppColors.storyMe),
        const SizedBox(height: 12),
        row(name, chart.them, AppColors.storyThem),
        if (labels != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final l in labels!)
                  Text(l, style: AppText.micro.copyWith(color: AppColors.label2)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _Numbers(chart: chart),
      ],
    );
  }
}

/// Two bars against the bigger of the two.
class _BarsChart extends StatelessWidget {
  const _BarsChart({required this.chart});

  final StoryChart chart;

  @override
  Widget build(BuildContext context) {
    final top = [chart.me.value, chart.them.value].reduce((a, b) => a > b ? a : b);
    Widget bar(ChartSide side, Color colour) {
      final share = top <= 0 ? 0.0 : side.value / top;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  side.label.toUpperCase(),
                  style: AppText.micro.copyWith(color: AppColors.label, letterSpacing: 1),
                ),
              ),
              Text(side.display, style: AppText.tileNumber(30)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: AppColors.storyTrack)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: share),
                    duration: const Duration(milliseconds: 1300),
                    curve: Ease.emphasised,
                    builder: (context, w, _) => FractionallySizedBox(
                      widthFactor: w.clamp(0, 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colour,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        bar(chart.me, AppColors.storyMe),
        const SizedBox(height: 18),
        bar(chart.them, AppColors.storyThem),
      ],
    );
  }
}

/// Two big numbers, side by side.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.chart});

  final StoryChart chart;

  @override
  Widget build(BuildContext context) {
    Widget one(ChartSide side, Color colour) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(side.display, style: AppText.tileNumber(44).copyWith(color: colour)),
            ),
            const SizedBox(height: 4),
            Text(side.label, style: AppText.footnote.copyWith(color: AppColors.label)),
          ],
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: one(chart.me, AppColors.storyMe)),
        const SizedBox(width: 12),
        Expanded(child: one(chart.them, AppColors.storyThem)),
      ],
    );
  }
}

/// Two cards, each in its own category's colours: where they differ.
class _Versus extends StatelessWidget {
  const _Versus({required this.chart});

  final StoryChart chart;

  @override
  Widget build(BuildContext context) {
    Widget card(ChartSide side) => Container(
          height: 210,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: TileTones.of(side.category.tone),
            borderRadius: BorderRadius.circular(Radii.tile),
            border: Border.all(color: AppColors.tileEdge, width: 0.67),
            boxShadow: const [BoxShadow(color: AppColors.liquidShadow, blurRadius: 24)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(side.display, style: AppText.tileNumber(30)),
              ),
              const SizedBox(height: 6),
              Text(
                side.label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.tileCaption,
              ),
            ],
          ),
        );
    return Row(
      children: [
        Expanded(child: card(chart.me)),
        const SizedBox(width: 12),
        Expanded(child: card(chart.them)),
      ],
    );
  }
}
