import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';
import 'enums.dart';
import 'media.dart';

/// The typed half of an insight.
///
/// The server also sends a formatted [Insight.displayValue], and that is
/// what gets rendered. This is kept so the UI can size and shape a tile by
/// what the number means rather than by how long its string is.
@immutable
class TileValue {
  const TileValue({
    required this.kind,
    required this.number,
    this.entityLabel,
    this.entityRef,
  });

  final ValueKind kind;
  final double number;

  /// Set when the value is a thing rather than a quantity: a restaurant, a
  /// channel, a show.
  final String? entityLabel;
  final String? entityRef;

  static TileValue fromJson(Json j) => TileValue(
        kind: ValueKind.parse(j.strOrNull('kind')),
        number: j.decimal('number'),
        entityLabel: j.strOrNull('entity_label'),
        entityRef: j.strOrNull('entity_ref'),
      );
}

/// A derived tile: a fact the server computed, with a caption around it.
///
/// The value is never written by a model. A model may propose what to count
/// and phrase the caption; the number itself always comes from code, which is
/// why a tile can be trusted on a profile.
@immutable
class Insight {
  const Insight({
    required this.key,
    required this.origin,
    required this.category,
    required this.value,
    required this.displayValue,
    required this.caption,
    required this.support,
    required this.providers,
    required this.computedAt,
  });

  /// Stable across refreshes, so a picked tile keeps its place when the data
  /// behind it is pulled again.
  final String key;

  final TileOrigin origin;
  final TileCategory category;
  final TileValue value;

  /// Server-formatted. Never format a number on the client: the grouping and
  /// the currency would drift from the server's.
  final String displayValue;

  final String caption;

  /// How many records stand behind this. Confidence, roughly.
  final int support;

  final List<SourceProvider> providers;

  /// When this was computed. A tile from a year ago still claims today's
  /// taste, so the age is shown rather than hidden.
  final DateTime computedAt;

  static Insight fromJson(Json j) => Insight(
        key: j.str('key'),
        origin: TileOrigin.parse(j.strOrNull('origin')),
        category: TileCategory.parse(j.strOrNull('category')),
        value: TileValue.fromJson(j.object('value')),
        displayValue: j.str('display_value'),
        caption: j.str('caption'),
        support: j.intOr('support', 0),
        providers: j
            .strings('providers')
            .map(SourceProvider.parse)
            .toList(growable: false),
        computedAt: j.time('computed_at'),
      );

  static List<Insight> listFrom(List<Json> items) =>
      items.map(Insight.fromJson).toList(growable: false);
}

/// A question from the prompt bank.
@immutable
class Prompt {
  const Prompt({
    required this.key,
    required this.category,
    required this.text,
    required this.kind,
    required this.options,
    required this.starter,
    this.maxChars,
  });

  final String key;
  final TileCategory category;
  final String text;
  final AnswerKind kind;
  final List<PromptOption> options;
  final int? maxChars;

  /// One per category is marked a starter: the question to lead with when a
  /// person has nothing in that category yet.
  final bool starter;

  static Prompt fromJson(Json j) => Prompt(
        key: j.str('key'),
        category: TileCategory.parse(j.strOrNull('category')),
        text: j.str('text'),
        kind: AnswerKind.parse(j.strOrNull('kind')),
        options: j
            .objects('options')
            .map(PromptOption.fromJson)
            .toList(growable: false),
        maxChars: j.intOrNull('max_chars'),
        starter: j.flag('starter'),
      );
}

@immutable
class PromptOption {
  const PromptOption({required this.key, required this.label});

  final String key;
  final String label;

  static PromptOption fromJson(Json j) =>
      PromptOption(key: j.str('key'), label: j.str('label'));

  static List<PromptOption> listFrom(List<Json> items) =>
      items.map(PromptOption.fromJson).toList(growable: false);
}

/// A person's own answer to a prompt. Visibly distinct from a derived tile on
/// the profile, because a typed number that looks computed would make the
/// whole product forgeable.
@immutable
class PromptAnswer {
  const PromptAnswer({
    required this.promptKey,
    required this.category,
    required this.question,
    required this.kind,
    required this.answer,
    required this.answeredAt,
    this.option,
  });

  final String promptKey;
  final TileCategory category;
  final String question;
  final AnswerKind kind;
  final String answer;
  final String? option;
  final DateTime answeredAt;

  static PromptAnswer fromJson(Json j) => PromptAnswer(
        promptKey: j.str('prompt_key'),
        category: TileCategory.parse(j.strOrNull('category')),
        question: j.str('question'),
        kind: AnswerKind.parse(j.strOrNull('kind')),
        answer: j.str('answer'),
        option: j.strOrNull('option'),
        answeredAt: j.time('answered_at'),
      );

  static List<PromptAnswer> listFrom(List<Json> items) =>
      items.map(PromptAnswer.fromJson).toList(growable: false);
}

/// One tile as it appears on a profile: either a derived insight or an answer.
///
/// The two arrive as one list in one order, because that is the order the
/// person arranged them in.
@immutable
class ProfileTile {
  const ProfileTile({
    required this.kind,
    required this.key,
    required this.category,
    this.insight,
    this.prompt,
    this.media,
  });

  final TileKind kind;
  final String key;
  final TileCategory category;
  final Insight? insight;
  final PromptAnswer? prompt;

  /// What the tile leads with. An insight shows its number; an answer shows
  /// the answer, with the question above it.
  String get headline => insight?.displayValue ?? prompt?.answer ?? '';

  /// The line under the headline.
  String get body => insight?.caption ?? '';

  /// Set only on an answer tile.
  String? get question => prompt?.question;

  bool get isAnswer => kind == TileKind.prompt;

  /// The photo or video the person put behind it, if any. It belongs to the
  /// tile rather than the profile, so it survives the tile being dropped and
  /// picked again.
  final MediaAsset? media;

  static ProfileTile fromJson(Json j) {
    final insight = j.objectOrNull('insight');
    final prompt = j.objectOrNull('prompt');
    return ProfileTile(
      kind: TileKind.parse(j.strOrNull('kind')),
      key: j.str('key'),
      category: TileCategory.parse(j.strOrNull('category')),
      insight: insight == null ? null : Insight.fromJson(insight),
      prompt: prompt == null ? null : PromptAnswer.fromJson(prompt),
      media: _media(j),
    );
  }

  static List<ProfileTile> listFrom(List<Json> items) =>
      items.map(ProfileTile.fromJson).toList(growable: false);

  /// The shape sent back when the order or the selection changes.
  Json toRef() => {'kind': kind.wire, 'key': key};
}

MediaAsset? _media(Json j) {
  final m = j.objectOrNull('media');
  return m == null ? null : MediaAsset.fromJson(m);
}

/// What is behind one tile, picked or not. The picker's candidates carry no
/// media of their own, so it reads these alongside them.
@immutable
class TileMediaEntry {
  const TileMediaEntry({
    required this.kind,
    required this.key,
    required this.media,
  });

  final TileKind kind;
  final String key;
  final MediaAsset media;

  static TileMediaEntry fromJson(Json j) => TileMediaEntry(
        kind: TileKind.parse(j.strOrNull('kind')),
        key: j.str('key'),
        media: MediaAsset.fromJson(j.object('media')),
      );

  static List<TileMediaEntry> listFrom(List<Json> items) =>
      items.map(TileMediaEntry.fromJson).toList(growable: false);
}
