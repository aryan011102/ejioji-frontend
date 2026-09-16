import 'package:flutter/material.dart';

import '../widgets/tiles.dart';

/// Placeholder content, so the screens can be run and reviewed before the API
/// exists.
///
/// Everything in this file is replaced by a repository call. It is kept in one
/// place, and nothing outside `presentation` imports it, so deleting this file
/// is the checklist for "is the backend wired up yet" — if it deletes cleanly,
/// it is.
abstract final class Demo {
  static const meName = 'Ananya Garg';
  static const themName = 'Rohan Mehta';
  static const themFirst = 'Rohan';

  static const meSeed = Color(0xFF9C7A86);
  static const themSeed = Color(0xFF7B8E88);

  static const photos = [
    Color(0xFF7B8E88),
    Color(0xFF93867B),
    Color(0xFF6E7A93),
  ];

  static const pills = [
    ('📍', 'Bengaluru'),
    ('🎂', '31'),
    ('💻', 'Civil engineer'),
    ('🏢', 'L&T'),
    ('🎓', 'B.Tech, NIT Surathkal'),
  ];

  /// The wall a stranger meets.
  static const wall = <DemoInsight>[
    DemoInsight(
      id: 'p1',
      glyph: '🍜',
      number: '3:12 AM',
      caption: 'Latest biryani order of the year. A Tuesday.',
      size: TileSize.wide,
      tone: 'night',
      media: true,
    ),
    DemoInsight(
      id: 'p2',
      glyph: '🎧',
      number: 'Kasoor',
      caption: 'Prateek Kuhad · 214 plays, more than any other track',
      size: TileSize.large,
      tone: 'berry',
      track: true,
    ),
    DemoInsight(
      id: 'p3',
      glyph: '🏃',
      number: '6:10 AM',
      caption: 'Usual start of a run. Even in December.',
      size: TileSize.small,
      tone: 'moss',
    ),
    DemoInsight(
      id: 'p4',
      glyph: '✈️',
      number: 'Coorg',
      caption: 'The one place returned to three years running.',
      size: TileSize.small,
      tone: 'cobalt',
      media: true,
    ),
    DemoInsight(
      id: 'p5',
      glyph: '🎟️',
      number: '9',
      caption: 'Live gigs this year. Six standing, three seated.',
      size: TileSize.wide,
      tone: 'indigo',
    ),
    DemoInsight(
      id: 'p6',
      glyph: '🍜',
      number: '9 Tuesdays',
      caption: 'In a row. Same paneer roll, same place, 8:40 PM.',
      size: TileSize.small,
      tone: 'cocoa',
    ),
    DemoInsight(
      id: 'p7',
      glyph: '🛍️',
      prompt: 'The purchase still being defended',
      answer: 'An espresso machine that gets used exactly once a week.',
      size: TileSize.wide,
      tone: 'teal',
    ),
    DemoInsight(
      id: 'p8',
      glyph: '📺',
      number: '48 min',
      caption: 'Longest video watched to the end. Knife sharpening.',
      size: TileSize.small,
      tone: 'slate',
      media: true,
    ),
  ];

  static const categories = <DemoCategory>[
    DemoCategory(
      id: 'food',
      glyph: '🍜',
      name: 'Food and delivery',
      source: 'Swiggy and Zomato',
      lastRead: '2 days ago',
      picked: ['f2', 'f3'],
      insights: [
        DemoInsight(
          id: 'f1',
          number: '312',
          caption: 'Orders this year. Two hundred of them after 9 PM.',
          size: TileSize.wide,
          tone: 'saffron',
        ),
        DemoInsight(
          id: 'f2',
          number: '3:12 AM',
          caption: 'Latest biryani order of the year. A Tuesday.',
          size: TileSize.wide,
          tone: 'night',
          media: true,
        ),
        DemoInsight(
          id: 'f3',
          number: '9 Tuesdays',
          caption: 'In a row. Same paneer roll, same place, 8:40 PM.',
          size: TileSize.small,
          tone: 'cocoa',
        ),
        DemoInsight(
          id: 'f4',
          number: '62%',
          caption: 'From one kitchen. Loyalty, or laziness.',
          size: TileSize.small,
          tone: 'chilli',
        ),
        DemoInsight(
          id: 'f5',
          number: '₹184',
          caption: 'Average order. Mostly for one.',
          size: TileSize.small,
          tone: 'olive',
        ),
        DemoInsight(
          id: 'f6',
          number: '17',
          caption: 'Desserts ordered alone, at night.',
          size: TileSize.small,
          tone: 'rose',
        ),
      ],
    ),
    DemoCategory(
      id: 'music',
      glyph: '🎧',
      name: 'Music',
      source: 'Spotify',
      lastRead: 'today',
      picked: ['m1'],
      insights: [
        DemoInsight(
          id: 'm1',
          number: 'Kasoor',
          caption: 'Prateek Kuhad · 214 plays, more than any other track',
          size: TileSize.large,
          tone: 'berry',
          track: true,
        ),
        DemoInsight(
          id: 'm2',
          number: '41,203',
          caption: 'Minutes this year. Six full days of it.',
          size: TileSize.small,
          tone: 'indigo',
        ),
        DemoInsight(
          id: 'm3',
          number: '9',
          caption: 'Genres in one week. Ghazals next to techno.',
          size: TileSize.small,
          tone: 'teal',
        ),
        DemoInsight(
          id: 'm4',
          number: '3:07 AM',
          caption: 'Longest listening session ended here.',
          size: TileSize.wide,
          tone: 'slate',
        ),
      ],
    ),
    DemoCategory(
      id: 'fitness',
      glyph: '🏃',
      name: 'Moving',
      source: 'Apple Health and Strava',
      lastRead: '3 weeks ago',
      stale: true,
      picked: ['r1'],
      insights: [
        DemoInsight(
          id: 'r1',
          number: '6:10 AM',
          caption: 'Usual start of a run. Even in December.',
          size: TileSize.small,
          tone: 'moss',
        ),
        DemoInsight(
          id: 'r2',
          number: '1,204 km',
          caption: 'This year. Mostly the same loop.',
          size: TileSize.small,
          tone: 'olive',
        ),
        DemoInsight(
          id: 'r3',
          number: '142',
          caption: 'Workouts. Only eleven of them indoors.',
          size: TileSize.wide,
          tone: 'cobalt',
        ),
      ],
    ),
    DemoCategory(
      id: 'travel',
      glyph: '✈️',
      name: 'Travel',
      source: 'Gmail receipts',
      lastRead: 'yesterday',
      picked: ['t1'],
      insights: [
        DemoInsight(
          id: 't1',
          number: 'Coorg',
          caption: 'The one place returned to three years running.',
          size: TileSize.wide,
          tone: 'cobalt',
          media: true,
        ),
        DemoInsight(
          id: 't2',
          number: '11',
          caption: 'Trips this year. Six states, no repeats but one.',
          size: TileSize.small,
          tone: 'moss',
        ),
        DemoInsight(
          id: 't3',
          number: '43 days',
          caption: 'Average booked ahead. Rarely last-minute.',
          size: TileSize.small,
          tone: 'slate',
        ),
      ],
    ),
    DemoCategory(
      id: 'watch',
      glyph: '📺',
      name: 'Watching',
      source: 'YouTube',
      lastRead: '2 days ago',
      picked: ['w1'],
      insights: [
        DemoInsight(
          id: 'w1',
          number: '48 min',
          caption: 'Longest video watched to the end. Knife sharpening.',
          size: TileSize.wide,
          tone: 'slate',
          media: true,
        ),
        DemoInsight(
          id: 'w2',
          number: '96',
          caption: 'Channels subscribed. Forty of them about food.',
          size: TileSize.small,
          tone: 'chilli',
        ),
        DemoInsight(
          id: 'w3',
          number: '22',
          caption: 'Films in a cinema this year.',
          size: TileSize.small,
          tone: 'indigo',
        ),
      ],
    ),
  ];

  static const threads = <DemoThread>[
    DemoThread(
      id: 'c1',
      name: themName,
      seed: themSeed,
      last: 'Which place? I have opinions about paneer rolls.',
      when: '2m',
      unread: 2,
      starred: true,
    ),
    DemoThread(
      id: 'c2',
      name: 'Meera Iyer',
      seed: Color(0xFF93867B),
      last: "Okay the Coorg thing settles it, we're going.",
      when: '1h',
      starred: true,
    ),
    DemoThread(
      id: 'c3',
      name: 'Divya Nair',
      seed: Color(0xFF7A8E93),
      last: 'You: sent a photo',
      when: 'Yesterday',
    ),
  ];

  static const requests = <DemoThread>[
    DemoThread(
      id: 'r1',
      name: 'Aarav Sharma',
      seed: Color(0xFF8E7B93),
      last: 'Hi! Your profile made me laugh, the dessert one especially.',
      when: '3h',
    ),
    DemoThread(
      id: 'r2',
      name: 'Kabir Shah',
      seed: Color(0xFF8B7F6E),
      last: "Hello, saw we're both in Bengaluru. How's the week going?",
      when: '1d',
    ),
  ];

  static const messages = <DemoMessage>[
    DemoMessage(
      mine: false,
      text: '9 Tuesdays in a row is a commitment. Which place?',
      at: '9:04',
    ),
    DemoMessage(
      mine: true,
      text: 'Sri Sagar in Indiranagar. The paneer roll is not even the best '
          'thing there, it\'s just the thing I order.',
      at: '9:07',
    ),
    DemoMessage(mine: false, text: 'Which is the best thing then', at: '9:08'),
    DemoMessage(
      mine: true,
      text: 'Kesari bath. I will not be defending this.',
      at: '9:11',
      read: true,
    ),
  ];
}

@immutable
class DemoInsight {
  const DemoInsight({
    required this.id,
    required this.size,
    this.glyph,
    this.number,
    this.caption,
    this.prompt,
    this.answer,
    this.tone,
    this.media = false,
    this.track = false,
  });

  final String id;
  final TileSize size;
  final String? glyph;
  final String? number;
  final String? caption;
  final String? prompt;
  final String? answer;
  final String? tone;
  final bool media;
  final bool track;
}

@immutable
class DemoCategory {
  const DemoCategory({
    required this.id,
    required this.glyph,
    required this.name,
    required this.source,
    required this.lastRead,
    required this.picked,
    required this.insights,
    this.stale = false,
  });

  final String id;
  final String glyph;
  final String name;
  final String source;
  final String lastRead;
  final List<String> picked;
  final List<DemoInsight> insights;
  final bool stale;
}

@immutable
class DemoThread {
  const DemoThread({
    required this.id,
    required this.name,
    required this.seed,
    required this.last,
    required this.when,
    this.unread = 0,
    this.starred = false,
  });

  final String id;
  final String name;
  final Color seed;
  final String last;
  final String when;
  final int unread;
  final bool starred;
}

@immutable
class DemoMessage {
  const DemoMessage({
    required this.mine,
    required this.text,
    required this.at,
    this.read = false,
  });

  final bool mine;
  final String text;
  final String at;
  final bool read;
}
