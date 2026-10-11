import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// What leaves the phone from an Instagram "Download your information" zip.
///
/// The zip holds every direct message, so it is opened here and only two kinds
/// of thing are sent (Aryan, 2026-10-11, "all data except friends"):
///
///  * whole files that are about the person's own activity on other people's
///    public posts: who they follow, what they liked, saved, watched, commented
///    on, reposted, voted on and searched for, the songs they saved, and their
///    own grid posts. The server refuses any other file.
///  * `from_phone`, worked out here from files that never leave: when each
///    message they sent went and the words and emoji they use most in those
///    messages (never a message, never who it went to, names taken out), when
///    they posted stories (the stories file also lists the device and camera),
///    and their bio (the profile file also holds their phone number and date of
///    birth).
///
/// Never read at all: other people's messages beyond telling whose a message
/// is, `posts.html` (it says where each post was taken), logins, devices,
/// contacts and everything else.
class InstagramDownload {
  const InstagramDownload._();

  /// The files sent whole, by the name the server knows them as, and where
  /// each sits in the zip. Matched on the end of the path: the zip may wrap
  /// them in a folder of its own.
  static const files = {
    'following': 'connections/followers_and_following/following.html',
    'liked_posts': 'your_instagram_activity/likes/liked_posts.html',
    'saved_posts': 'your_instagram_activity/saved/saved_posts.html',
    'videos_watched': 'ads_information/ads_and_topics/videos_watched.html',
    'posts_viewed': 'ads_information/ads_and_topics/posts_viewed.html',
    'reels_comments': 'your_instagram_activity/comments/reels_comments.html',
    'story_likes': 'your_instagram_activity/story_interactions/story_likes.html',
    'polls': 'your_instagram_activity/story_interactions/polls.html',
    'emoji_sliders':
        'your_instagram_activity/story_interactions/emoji_sliders.html',
    'reposts': 'your_instagram_activity/media/reposts.html',
    'saved_music': 'your_instagram_activity/saved/saved_music.html',
    'profile_searches':
        'logged_information/recent_searches/profile_searches.html',
  };

  /// Files Instagram splits into numbered pages, sent as a list. `posts_N`,
  /// never `posts.html`, which lists where each post was taken.
  static final paged = {
    'post_comments':
        RegExp(r'(^|/)your_instagram_activity/comments/post_comments_\d+\.html$'),
    'posts': RegExp(r'(^|/)your_instagram_activity/media/posts_\d+\.html$'),
  };

  /// The server takes at most this many pages of one file.
  static const maxPages = 20;

  static final _profile =
      RegExp(r'(^|/)personal_information/personal_information/personal_information\.html$');
  static final _stories =
      RegExp(r'(^|/)your_instagram_activity/media/stories\.html$');
  static final _inbox = RegExp(
    r'(^|/)your_instagram_activity/messages/inbox/[^/]+/message_\d+\.html$',
  );

  /// The body the upload sends: the files, and `from_phone` when there is
  /// anything to put in it. Empty when the zip holds none of the files.
  static Map<String, Object> read(String path) {
    final input = InputFileStream(path);
    try {
      return fromArchive(ZipDecoder().decodeStream(input));
    } finally {
      input.closeSync();
    }
  }

  static Map<String, Object> fromArchive(Archive zip) {
    final body = <String, Object>{};
    final pages = <String, List<(String, String)>>{};
    String? profile;
    String? stories;
    final threads = <String>[];

    String text(ArchiveFile f) => utf8.decode(f.content, allowMalformed: true);

    for (final entry in zip.files) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll(r'\', '/');
      for (final MapEntry(key: key, value: suffix) in files.entries) {
        if (name == suffix || name.endsWith('/$suffix')) body[key] = text(entry);
      }
      for (final MapEntry(key: key, value: pattern) in paged.entries) {
        if (pattern.hasMatch(name)) {
          (pages[key] ??= []).add((name, text(entry)));
        }
      }
      if (_profile.hasMatch(name)) profile = text(entry);
      if (_stories.hasMatch(name)) stories = text(entry);
      if (_inbox.hasMatch(name)) threads.add(text(entry));
    }
    for (final MapEntry(key: key, value: found) in pages.entries) {
      found.sort((a, b) => _pageNumber(a.$1).compareTo(_pageNumber(b.$1)));
      body[key] = [for (final (_, t) in found.take(maxPages)) t];
    }
    if (body.isEmpty) return body;

    final phone = fromPhone(
      profile: profile,
      stories: stories,
      threads: threads,
    );
    if (phone.isNotEmpty) body['from_phone'] = phone;
    return body;
  }

  static int _pageNumber(String name) =>
      int.tryParse(RegExp(r'_(\d+)\.html$').firstMatch(name)?.group(1) ?? '') ??
      0;

  // ---- What the phone works out itself ----

  /// The server's limits on what the phone may send.
  static const maxSent = 60000;
  static const maxStories = 5000;
  static const maxWords = 60;
  static const maxEmoji = 40;
  static const maxBio = 1000;

  static final _time =
      RegExp(r'<div class="_3-94 _a6-o">([A-Z][a-z]{2} \d{2}, \d{4} \d{1,2}:\d{2} [ap]m)</div>');
  static final _header =
      RegExp(r'<time datetime="\d{4}-\d{2}-\d{2}T\d{2}:\d{2}Z">[^<]*</time>');
  static final _block = RegExp(r'<div class="pam _3-95 _2ph- _a6-g uiBoxWhite noborder">');
  static final _sender = RegExp(r'<h2 class="[^"]*">([^<]*)</h2>');
  static final _content =
      RegExp(r'<div class="_3-95 _a6-p"><div><div></div><div>([^<]*)</div>');
  static final _title = RegExp(r'<title>([^<]*)</title>');

  /// `from_phone`, from the profile file, the stories file and the message
  /// threads. Nothing of a message is kept but when the person's own went, and
  /// the words and emoji in them, counted. Without the profile file there is no
  /// telling whose message is whose, so no message is read at all.
  static Map<String, Object> fromPhone({
    String? profile,
    String? stories,
    List<String> threads = const [],
  }) {
    final out = <String, Object>{};
    final me = profile == null ? null : ownerOf(profile);

    final sent = <String>[];
    final words = <String, int>{};
    final emoji = <String, int>{};
    String? header;
    if (me != null && me.names.isNotEmpty) {
      // Everyone named anywhere in the threads, so no name is counted as a word.
      final names = <String>{...me.names.expand(_wordsOfName)};
      for (final thread in threads) {
        for (final m in _sender.allMatches(thread)) {
          names.addAll(_wordsOfName(unescape(m.group(1)!)));
        }
        final title = _title.firstMatch(thread)?.group(1);
        if (title != null) names.addAll(_wordsOfName(unescape(title)));
      }
      for (final thread in threads) {
        var mine = false;
        for (final chunk in thread.split(_block).skip(1)) {
          final who = _sender.firstMatch(chunk)?.group(1);
          final when = _time.firstMatch(chunk)?.group(1);
          if (who == null || when == null) continue;
          if (!me.names.contains(unescape(who).trim())) continue;
          mine = true;
          sent.add(when);
          final said = _content.firstMatch(chunk)?.group(1);
          if (said == null) continue;
          final line = unescape(said).trim();
          if (isSystemLine(line)) continue;
          for (final w in wordsOf(line)) {
            if (!names.contains(w)) words[w] = (words[w] ?? 0) + 1;
          }
          for (final e in emojiOf(line)) {
            emoji[e] = (emoji[e] ?? 0) + 1;
          }
        }
        if (mine) header ??= _header.firstMatch(thread)?.group(0);
      }
    }

    final storyTimes = stories == null
        ? const <String>[]
        : [for (final m in _time.allMatches(stories)) m.group(1)!];
    if (stories != null && storyTimes.isNotEmpty) {
      header ??= _header.firstMatch(stories)?.group(0);
    }
    if (header != null && header.length <= 500) {
      if (sent.isNotEmpty) out['dm_sent'] = _latest(sent, maxSent);
      if (storyTimes.isNotEmpty) {
        out['stories'] = _latest(storyTimes, maxStories);
      }
      if (out.isNotEmpty) out['header'] = header;
    }
    if (words.isNotEmpty) out['dm_words'] = _top(words, maxWords);
    if (emoji.isNotEmpty) out['dm_emoji'] = _top(emoji, maxEmoji);
    final bio = me?.bio;
    if (bio != null && bio.isNotEmpty && bio.length <= maxBio) out['bio'] = bio;
    return out;
  }

  /// Files list newest first, so the first ones are the latest.
  static List<String> _latest(List<String> times, int most) =>
      times.length <= most ? times : times.sublist(0, most);

  static Map<String, int> _top(Map<String, int> counts, int most) {
    final ranked = counts.entries.toList()
      ..sort(
        (a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key),
      );
    return {
      for (final e in ranked.take(most))
        e.key: e.value > 10000000 ? 10000000 : e.value,
    };
  }

  /// The person's name and username as the profile file prints them (what
  /// their own messages are signed with), and their bio.
  static ({Set<String> names, String? bio}) ownerOf(String profile) {
    String? field(String label) {
      final m = RegExp('>$label<div><div>([^<]*)</div>').firstMatch(profile);
      final v = m == null ? null : unescape(m.group(1)!).trim();
      return v == null || v.isEmpty ? null : v;
    }

    return (
      names: {
        for (final v in [field('Name'), field('Username')])
          if (v != null) v,
      },
      bio: field('Bio'),
    );
  }

  // ---- Lines Instagram writes itself ----

  static final _system = [
    RegExp(r'sent an attachment\.?$', caseSensitive: false),
    RegExp(r'^(\S+ )?liked a message$', caseSensitive: false),
    RegExp(r'^(\S+ )?reacted .{1,16} to (your|a) message$', caseSensitive: false),
    RegExp(r'^you sent a private reply to a comment', caseSensitive: false),
    RegExp(r'sent a voice message\.?$', caseSensitive: false),
    RegExp(
      r'(started|ended|missed) (a |an )?(video|audio) (chat|call)',
      caseSensitive: false,
    ),
    RegExp(r'(video|audio) (chat|call) ended', caseSensitive: false),
    RegExp(r'unsent a message', caseSensitive: false),
    RegExp(
      r'(shared|replied to|reacted to|mentioned you in) (a |your |their )?story',
      caseSensitive: false,
    ),
    RegExp(
      r'(named|changed|left|joined|added .+ to) the group',
      caseSensitive: false,
    ),
  ];

  /// Whether a message's text is something Instagram wrote ("You sent an
  /// attachment.") rather than the person.
  static bool isSystemLine(String line) =>
      line.isEmpty || _system.any((p) => p.hasMatch(line));

  // ---- Words ----

  static final _link = RegExp(r'(https?://|www\.)\S+', caseSensitive: false);
  static final _wordish = RegExp(r'[\p{L}\p{M}]+', unicode: true);
  static final _mark = RegExp(r'\p{M}', unicode: true);

  /// Words carry no meaning on their own here, in English or Hindi. The rest
  /// ("haan", "bhai", "yaar") is what the tile is for.
  static const stopWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'if', 'of', 'to', 'in', 'on', 'at',
    'for', 'with', 'from', 'by', 'as', 'is', 'am', 'are', 'was', 'were', 'be',
    'been', 'it', 'its', 'this', 'that', 'these', 'those', 'i', 'me', 'my',
    'you', 'your', 'u', 'ur', 'we', 'us', 'our', 'he', 'she', 'him', 'her',
    'his', 'they', 'them', 'their', 'so', 'do', 'did', 'does', 'have', 'has',
    'had', 'will', 'would', 'can', 'could', 'not', 'no', 'just', 'also',
    'too', 'there', 'here', 'what', 'when', 'where', 'how', 'then', 'than',
    'hai', 'hain', 'ho', 'ka', 'ki', 'ke', 'ko', 'se', 'mein', 'main', 'tu',
    'tum', 'ye', 'yeh', 'wo', 'woh', 'bhi', 'aur', 'kya', 'na', 'hi', 'tha',
    'thi',
  };

  /// The words of a message as the server takes them: letters only, two to
  /// twenty-four of them, lowercase. A word with a vowel sign or a digit in it
  /// is left out rather than sent, since the server would refuse the body.
  static Iterable<String> wordsOf(String line) sync* {
    for (final m in _wordish.allMatches(line.replaceAll(_link, ' '))) {
      final w = m.group(0)!.toLowerCase();
      if (w.length < 2 || w.length > 24 || _mark.hasMatch(w)) continue;
      if (stopWords.contains(w)) continue;
      yield w;
    }
  }

  static Iterable<String> _wordsOfName(String name) => _wordish
      .allMatches(name)
      .map((m) => m.group(0)!.toLowerCase())
      .where((w) => w.length >= 2);

  // ---- Emoji ----

  static final _symbol = RegExp(r'^[\p{So}\p{Sk}]$', unicode: true);
  static final _pictograph =
      RegExp(r'[\p{Extended_Pictographic}\u{1F1E6}-\u{1F1FF}]', unicode: true);
  static const _joiners = {0x200D, 0xFE0F, 0x20E3};

  /// The emoji in a message, one per use. Only what the server would take:
  /// every character a symbol or a joiner, at most ten, and a picture among
  /// them, so "^_^" is not an emoji and a keycap "1️⃣" is left out.
  static Iterable<String> emojiOf(String line) sync* {
    for (final g in line.characters) {
      final runes = g.runes.toList();
      if (runes.length > 10) continue;
      final symbols = runes.every(
        (r) => _joiners.contains(r) || _symbol.hasMatch(String.fromCharCode(r)),
      );
      if (symbols && _pictograph.hasMatch(g)) yield g;
    }
  }

  // ---- HTML ----

  static final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos|#39);');

  static String unescape(String s) => s.replaceAllMapped(_entity, (m) {
        final e = m.group(1)!;
        return switch (e) {
          'amp' => '&',
          'lt' => '<',
          'gt' => '>',
          'quot' => '"',
          'apos' || '#39' => "'",
          _ when e.startsWith('#x') =>
            String.fromCharCode(int.parse(e.substring(2), radix: 16)),
          _ => String.fromCharCode(int.parse(e.substring(1))),
        };
      });
}
