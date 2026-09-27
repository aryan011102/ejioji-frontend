import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

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

/// The song a tile is about, as Apple Music's catalog has it.
///
/// Set only on a tile about one song. The cover goes behind the tile unless
/// the person put their own photo or video there, and the preview plays on a
/// tap, never on its own. The preview is an ordinary audio file Apple serves,
/// so whoever is looking needs no Apple Music of their own.
@immutable
class SongMusic {
  const SongMusic({
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.artworkBackground,
    this.previewUrl,
    this.appleMusicUrl,
    this.spotifyUrl,
  });

  final String title;
  final String artist;
  final String? artworkUrl;

  /// The cover's main colour, to paint while the image loads.
  final Color? artworkBackground;

  /// Thirty seconds, streamed from Apple.
  final String? previewUrl;

  /// Where the Apple Music badge goes.
  final String? appleMusicUrl;
  final String? spotifyUrl;

  static SongMusic fromJson(Json j) => SongMusic(
        title: j.str('title'),
        artist: j.str('artist'),
        artworkUrl: j.strOrNull('artwork_url'),
        artworkBackground: _hex(j.strOrNull('artwork_background')),
        previewUrl: j.strOrNull('preview_url'),
        appleMusicUrl: j.strOrNull('apple_music_url'),
        spotifyUrl: j.strOrNull('spotify_url'),
      );

  static Color? _hex(String? six) {
    final v = six == null || six.length != 6 ? null : int.tryParse(six, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
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
    this.music,
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

  /// The song this tile is about, when it is about one Apple's catalog has.
  final SongMusic? music;

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
        music: _music(j),
      );

  static SongMusic? _music(Json j) {
    final m = j.objectOrNull('music');
    return m == null ? null : SongMusic.fromJson(m);
  }

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

  /// The song, on a tile about one.
  SongMusic? get music => insight?.music;

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

/// One of somebody's tiles as it read when it was sent with a chat request
/// or a message: "chat about this".
///
/// A copy, so it does not change when the tile does. [removed] means what it
/// rested on is gone (a source withdrawn, the answer deleted): say it was about
/// a tile that is no longer there, and show nothing of it.
@immutable
class TileQuote {
  const TileQuote({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.category,
    required this.quotedAt,
    required this.removed,
    this.valueKind,
    this.displayValue,
    this.caption,
    this.question,
    this.answer,
  });

  final String id;

  /// Whose tile it is. Always the other person in a request or a chat.
  final String ownerId;

  final TileKind kind;
  final TileCategory category;
  final DateTime quotedAt;
  final bool removed;

  /// Set on an insight that is still there.
  final ValueKind? valueKind;
  final String? displayValue;
  final String? caption;

  /// Set on an answer that is still there.
  final String? question;
  final String? answer;

  bool get isAnswer => kind == TileKind.prompt;

  static TileQuote fromJson(Json j) {
    final insight = j.objectOrNull('insight');
    final prompt = j.objectOrNull('prompt');
    return TileQuote(
      id: j.str('id'),
      ownerId: j.str('owner_id'),
      kind: TileKind.parse(j.strOrNull('kind')),
      category: TileCategory.parse(j.strOrNull('category')),
      quotedAt: j.time('quoted_at'),
      removed: j.flag('removed'),
      valueKind: insight == null
          ? null
          : ValueKind.parse(insight.strOrNull('value_kind')),
      displayValue: insight?.strOrNull('display_value'),
      caption: insight?.strOrNull('caption'),
      question: prompt?.strOrNull('question'),
      answer: prompt?.strOrNull('answer'),
    );
  }

  /// How a tile will look once quoted, for the chip above the keyboard and
  /// the bubble still sending, before the server has made the copy.
  static TileQuote preview(ProfileTile t) => TileQuote(
        id: '',
        ownerId: '',
        kind: t.kind,
        category: t.category,
        quotedAt: DateTime.now(),
        removed: false,
        valueKind: t.insight?.value.kind,
        displayValue: t.insight?.displayValue,
        caption: t.insight?.caption,
        question: t.prompt?.question,
        answer: t.prompt?.answer,
      );

  static TileQuote? maybe(Json j, String key) {
    final found = j.objectOrNull(key);
    return found == null ? null : TileQuote.fromJson(found);
  }
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
