import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/states.dart';

/// The four reading pages under Support and privacy.
///
/// Every sentence here is a claim about what the server does, so each one is
/// written from the consent notices and the code, not from what would be nice
/// to say. When the backend changes what it reads or keeps, this changes with
/// it, in the same week as the notice.

/// One line of fact: a short label, then what it means.
typedef _Fact = (String, String);

class _Section {
  const _Section(this.header, this.facts, {this.footer});

  final String header;
  final List<_Fact> facts;
  final String? footer;
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.title,
    required this.intro,
    required this.sections,
    this.note,
  });

  final String title;
  final String intro;
  final List<_Section> sections;

  /// A closing note, for the one thing on the page that most needs saying.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: title,
        backLabel: 'Support',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.titleGutter,
              0,
              Insets.titleGutter,
              20,
            ),
            child: Text(intro, style: AppText.callout),
          ),
          for (final s in sections)
            SectionGroup(
              header: s.header,
              footer: s.footer,
              children: [
                for (final (i, (label, body)) in s.facts.indexed)
                  _FactRow(
                    label: label,
                    body: body,
                    last: i == s.facts.length - 1,
                  ),
              ],
            ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              child: NoteCard(icon: Icons.info_outline, text: note!),
            ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.body, required this.last});

  final String label;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.bodyStrong),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: AppText.callout.copyWith(color: AppColors.label2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: AppColors.separator,
            ),
          ),
      ],
    );
  }
}

/// Per app, what is read once, what is kept, and what never is.
class WhatWeReadPage extends StatelessWidget {
  const WhatWeReadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoPage(
      title: 'What we read',
      intro: 'Each app is read once, while your profile is being built, and '
          'only after you say yes to it. We do not keep access afterwards, and '
          'we do not read it again unless you ask us to.',
      sections: [
        _Section('YouTube', [
          (
            'We read',
            'Your subscriptions, your liked videos, and the videos in your '
                'playlists, private ones included.',
          ),
          (
            'We never read',
            'The names or descriptions of your playlists. YouTube does not '
                'give anyone your watch history.',
          ),
        ]),
        _Section(
          'Gmail',
          [
            (
              'Food orders',
              'Zomato and Swiggy receipts. We keep the restaurant, when you '
                  'ordered, what you paid and the dishes.',
            ),
            (
              'Shopping',
              'Order confirmations from Myntra, Zara and H&M. We keep when it '
                  'arrived and, for each item, the brand, its name, its colour '
                  'and how many. Never the price or the size.',
            ),
            (
              'Bookings',
              'Flights, trains, stays, tickets, tours, tables and courts. We '
                  'never open these emails. We read who sent it, its subject '
                  'line and when it arrived, and keep only what kind of '
                  'booking it was, the site and the time.',
            ),
            (
              'We never read',
              'Any other email, or any attachment. We never keep an email '
                  'itself, your name, your address or how you paid.',
            ),
          ],
          footer: 'An order with something for a child, maternity, '
              'innerwear, religious, plus-size, medical or sexual wellness in '
              'it is left out entirely.',
        ),
        _Section('Spotify', [
          (
            'We read',
            'The listening history you upload. For each song played for 30 '
                'seconds or more: the artist, the song, when, and for how '
                'long.',
          ),
          (
            'We leave out',
            'Podcasts, audiobooks, private sessions, and the IP address, '
                'country and device Spotify lists with each play.',
          ),
        ]),
        _Section('Netflix', [
          (
            'We read',
            'The viewing history file you upload for your own profile: each '
                "title and the day you watched it. We don't keep the file.",
          ),
          (
            'We refuse',
            "Netflix's full data download. It covers everyone on the account, "
                'not just you.',
          ),
        ]),
        _Section('Apple Music', [
          (
            'We read',
            'The songs and albums in your library, with artist, album, genre, '
                'release year and length.',
          ),
          (
            'We never read',
            'Your playlists or their names. Apple does not give us your '
                'listening history. Anything filed under a devotional genre is '
                'not kept.',
          ),
        ]),
        _Section('DigiLocker', [
          (
            'We check',
            'Your first name and date of birth against your profile, once, for '
                'the verified tick. Then we throw them away.',
          ),
          (
            'We never receive',
            'Your Aadhaar number, photo, address or any document. Nothing '
                'from DigiLocker is used for matches or insights.',
          ),
        ]),
        _Section('The AI that suggests insights', [
          (
            'It is sent',
            'Totals and patterns, like "ordered biryani 14 times", and the '
                'names of what you like, order and play most. Only if you '
                'allow AI processing.',
          ),
          (
            'It is never sent',
            'Your emails, video or episode titles, amounts you paid, order '
                'numbers, where you travelled, your name or your phone number.',
          ),
          (
            'It never counts',
            'Every number on your profile is counted by theonebytwo. The AI '
                'only suggests what to count.',
          ),
        ]),
      ],
      note: 'Removing an app in Settings deletes everything we worked out from '
          'it.',
    );
  }
}

/// Who sees what, and when.
class WhatOthersSeePage extends StatelessWidget {
  const WhatOthersSeePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoPage(
      title: 'What others see',
      intro: 'Your profile shows what you chose for it, and nothing you did '
          'not. Here is who sees what.',
      sections: [
        _Section('Anyone shown your profile', [
          (
            'About you',
            'Your first name, age and city, and your pronouns, languages and '
                'education if you added them.',
          ),
          ('Your photos', 'The photos on your profile, in your order.'),
          (
            'Your tiles',
            'Only the tiles you picked, and any photo or video you put behind '
                'one. Tiles you left out are never shown.',
          ),
          (
            'Your tick',
            'If you verified with DigiLocker, the tick. Never what DigiLocker '
                'told us.',
          ),
        ]),
        _Section('After you match', [
          (
            'Your socials',
            'Instagram, X and LinkedIn, only while their switch is on in '
                'Settings.',
          ),
          ('Your messages', 'Only the two of you, in your chat.'),
          (
            'Your family page',
            'Only if you both say you are ready to share with family.',
          ),
        ]),
        _Section('When you look at someone', [
          (
            'Profile views',
            'If their profile is on your screen for a few seconds, you appear '
                'in their profile views.',
          ),
          (
            'Stealth mode',
            'In stealth you are out of every feed, only people you ask can see '
                'you, and your looks are not recorded.',
          ),
        ]),
      ],
      note: 'Insights you hide still help us find your matches. Other people '
          'never see them.',
    );
  }
}

/// The list of things that stay with us, or never exist at all.
class NeverShownPage extends StatelessWidget {
  const NeverShownPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoPage(
      title: 'Never shown',
      intro: 'Some things are never on your profile, whatever you pick. Some '
          'we never work out at all.',
      sections: [
        _Section('Never shown to anyone', [
          (
            'Money',
            'What you paid is never on a tile, never sent to the AI and never '
                'used for matches.',
          ),
          (
            'Your phone number',
            'Not to matches, and not to our own moderators.',
          ),
          ('Your last name', 'Only you see it.'),
          (
            'Your email addresses',
            'The Gmail accounts you connected are shown only to you.',
          ),
          (
            'Who you want to see',
            'Your "show me" choice and your filters stay with you.',
          ),
        ]),
        _Section('Never kept', [
          (
            'Addresses',
            'Your home address on a receipt, or the restaurant\'s, is never '
                'kept.',
          ),
          (
            'Emails',
            'We keep what an order said, never the email. Booking emails are '
                'never opened.',
          ),
          ('Contacts', 'We never read your phone\'s contacts.'),
        ]),
        _Section('Never worked out', [
          (
            'Religion, caste, health, sexuality',
            'Orders, songs, videos and shows that could point to these are '
                'left out before anything is counted, so they cannot show up '
                'on a tile or in a match.',
          ),
        ]),
        _Section('Never told', [
          (
            'A report',
            'Nobody is told who reported them.',
          ),
          (
            'A no',
            'If you decline a request, the person is not told. It just leaves '
                'their list.',
          ),
        ]),
      ],
    );
  }
}

/// Plain advice for meeting someone from a matrimonial app, most of it about
/// the money scam, because that is the one that happens.
class SafetyTipsPage extends StatelessWidget {
  const SafetyTipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoPage(
      title: 'Safety tips',
      intro: 'Most people here are who they say they are. These are for the '
          'few who are not.',
      sections: [
        _Section('Money', [
          (
            'Never send money',
            'Not for an emergency, a visa, customs, a gift or an investment. '
                'Someone who asks, however good the story, is the scam. Report '
                'them.',
          ),
          (
            'Never share codes',
            'An OTP, a UPI PIN, your Aadhaar or PAN. Nobody you are getting to '
                'know needs them.',
          ),
        ]),
        _Section('Getting to know someone', [
          (
            'Stay in the app for a while',
            'A rush to move to WhatsApp is how most scams start. You can report '
                'and block here.',
          ),
          (
            'Video call first',
            'Before meeting. Someone who keeps finding reasons not to is worth '
                'noticing.',
          ),
          (
            'The tick',
            'A verified tick means their name and date of birth matched '
                'DigiLocker. It is not a promise about the person.',
          ),
        ]),
        _Section('Meeting', [
          (
            'Somewhere busy',
            'Meet first in a public place, get there and back on your own, and '
                'tell someone where you will be.',
          ),
          (
            'Keep your address to yourself',
            'And your workplace, until you know them.',
          ),
        ]),
        _Section(
          'If something is wrong',
          [
            (
              'Report and block',
              'From their profile or your chat. Reporting always blocks, and '
                  'they are never told who reported them.',
            ),
            (
              'In danger',
              'Call 112, India\'s emergency number.',
            ),
            (
              'Lost money',
              'Call 1930, the national cyber crime helpline, or report at '
                  'cybercrime.gov.in, as soon as you can.',
            ),
          ],
        ),
      ],
    );
  }
}
