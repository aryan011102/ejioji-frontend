import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../shared/models/enums.dart';
import '../shared/models/media.dart';

/// Where the in common stories stand in one match.
enum InCommonState {
  /// This person has not said yes. Tapping the ring asks, once.
  ask('ask'),

  /// They have; the other person has not. Nothing is shown yet.
  waiting('waiting'),

  /// Both have, and the one line an AI writes is on its way. The stories are
  /// already usable: poll a few times, then open what there is.
  preparing('preparing'),
  ready('ready'),

  /// Both said yes and there is too little in common. No ring.
  notEnough('not_enough');

  const InCommonState(this.wire);
  final String wire;

  static InCommonState parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => notEnough);
}

enum StoryKind {
  intro('intro'),
  common('common'),
  thought('thought'),
  differ('differ');

  const StoryKind(this.wire);
  final String wire;

  static StoryKind parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => common);
}

enum ChartType {
  hours('hours'),
  weekdays('weekdays'),
  months('months'),
  bars('bars'),
  numbers('numbers'),
  versus('versus'),
  ranks('ranks'),
  names('names'),
  records('records'),
  // Each side's year of weeks, with its number: how often.
  year('year'),
  // No picture: the headline and footnote stand alone.
  words('words'),
  unknown('');

  const ChartType(this.wire);
  final String wire;

  static ChartType parse(String? raw) =>
      values.firstWhere((v) => v.wire == raw, orElse: () => unknown);
}

/// How often, across the year up to one person's latest row: a count per
/// week and per month. Never a date.
class StoryCalendar {
  const StoryCalendar({
    required this.weeks,
    required this.months,
    required this.firstMonth,
    required this.firstYear,
  });

  static StoryCalendar? fromJson(Json? j) {
    if (j == null) return null;
    final weeks = j.ints('weeks');
    final months = j.ints('months');
    if (weeks.isEmpty || months.isEmpty) return null;
    return StoryCalendar(
      weeks: weeks,
      months: months,
      firstMonth: j.intOr('first_month', 1),
      firstYear: j.intOr('first_year', 2000),
    );
  }

  /// Oldest first; the last holds the latest row.
  final List<int> weeks;

  /// Twelve calendar months, oldest first, from [firstMonth] of [firstYear].
  final List<int> months;
  final int firstMonth;
  final int firstYear;

  int get total => months.fold(0, (a, b) => a + b);
  int get weeksWithAny => weeks.where((w) => w > 0).length;
}

class ChartSide {
  const ChartSide({
    required this.value,
    required this.display,
    required this.label,
    required this.category,
    this.series = const [],
    this.calendar,
    this.name,
  });

  factory ChartSide.fromJson(Json j) => ChartSide(
        value: j.decimal('value'),
        display: j.str('display'),
        label: j.str('label'),
        category: TileCategory.parse(j.strOrNull('category')),
        series: j.ints('series'),
        calendar: StoryCalendar.fromJson(j.objectOrNull('calendar')),
        name: j.strOrNull('name'),
      );

  /// How the rows spread: 24 hours on an hours chart, 7 weekdays (Monday
  /// first) under the weekend story. Empty from an older server.
  final List<int> series;

  /// A year of how often, under a story about a count. Null when there is too
  /// little to draw, and then null on the other side too.
  final StoryCalendar? calendar;

  /// The named thing behind the number, drawn under it: the song under the
  /// year on a record. Null where the number names nothing.
  final String? name;

  /// The tile's own number: an hour 0 to 23, a weekday (Monday 0), a month
  /// (January 1), a count, a fraction, seconds or a year, by chart type.
  final double value;

  /// What the tile prints for it. Never formatted here: the server's
  /// formatting is the only one, so the story and the tile agree.
  final String display;
  final String label;
  final TileCategory category;
}

/// One place in a top five.
class RankRow {
  const RankRow({required this.label, required this.display, required this.shared});

  factory RankRow.fromJson(Json j) => RankRow(
        label: j.str('label'),
        display: j.str('display'),
        shared: j.flag('shared'),
      );

  final String label;
  final String display;

  /// In the other person's top five too: drawn lit.
  final bool shared;
}

class StoryChart {
  const StoryChart({
    required this.type,
    required this.me,
    required this.them,
    this.meRanks = const [],
    this.themRanks = const [],
  });

  factory StoryChart.fromJson(Json j) => StoryChart(
        type: ChartType.parse(j.strOrNull('type')),
        me: ChartSide.fromJson(j.object('me')),
        them: ChartSide.fromJson(j.object('them')),
        meRanks: j.objects('me_ranks').map(RankRow.fromJson).toList(),
        themRanks: j.objects('them_ranks').map(RankRow.fromJson).toList(),
      );

  final ChartType type;
  final ChartSide me;
  final ChartSide them;
  final List<RankRow> meRanks;
  final List<RankRow> themRanks;
}

class Story {
  const Story({
    required this.kind,
    required this.eyebrow,
    required this.title,
    this.category,
    this.footnote,
    this.chart,
    this.onProfileMe,
    this.onProfileThem,
  });

  factory Story.fromJson(Json j) {
    final category = j.strOrNull('category');
    final chart = j.objectOrNull('chart');
    return Story(
      kind: StoryKind.parse(j.strOrNull('kind')),
      category: category == null ? null : TileCategory.parse(category),
      eyebrow: j.str('eyebrow'),
      title: j.str('title'),
      footnote: j.strOrNull('footnote'),
      chart: chart == null ? null : StoryChart.fromJson(chart),
      onProfileMe: j['on_profile_me'] as bool?,
      onProfileThem: j['on_profile_them'] as bool?,
    );
  }

  final StoryKind kind;

  /// Which tile colours the slide wears. Null on the intro, the thought and a
  /// difference between two categories, which wear the brand's.
  final TileCategory? category;
  final String eyebrow;
  final String title;
  final String? footnote;
  final StoryChart? chart;
  final bool? onProfileMe;
  final bool? onProfileThem;
}

class StoryPerson {
  const StoryPerson({required this.firstName, this.photo});

  factory StoryPerson.fromJson(Json j) {
    final photo = j.objectOrNull('photo');
    return StoryPerson(
      firstName: j.str('first_name'),
      photo: photo == null ? null : MediaAsset.fromJson(photo),
    );
  }

  final String firstName;
  final MediaAsset? photo;
}

class InCommon {
  const InCommon({
    required this.state,
    required this.themSaidYes,
    required this.me,
    required this.them,
    required this.stories,
  });

  factory InCommon.fromJson(Json j) => InCommon(
        state: InCommonState.parse(j.strOrNull('state')),
        themSaidYes: j.flag('them_said_yes'),
        me: StoryPerson.fromJson(j.object('me')),
        them: StoryPerson.fromJson(j.object('them')),
        stories: j.objects('stories').map(Story.fromJson).toList(),
      );

  final InCommonState state;

  /// The other person has said yes, so the question can say so.
  final bool themSaidYes;
  final StoryPerson me;
  final StoryPerson them;

  /// Six to eight, in order. Empty until both have said yes.
  final List<Story> stories;

  bool get hasRing => state != InCommonState.notEnough;
  bool get canOpen =>
      (state == InCommonState.ready || state == InCommonState.preparing) &&
      stories.isNotEmpty;
}

/// The in common stories, worked out by the server from both people's
/// insights on every read. 404 for anything but an open match of yours.
class InCommonRepository {
  const InCommonRepository(this._api);

  final ApiClient _api;

  Future<InCommon> load(String matchId) async =>
      InCommon.fromJson(await _api.getJson(Api.inCommon(matchId)));
}
