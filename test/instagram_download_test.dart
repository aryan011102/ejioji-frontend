import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:ejioji/data/instagram_download.dart';
import 'package:flutter_test/flutter_test.dart';

/// The layout of a real download (2026-10-09), with made-up people and words.
const _header = '<header><aside>Generated on '
    '<time datetime="2026-10-09T16:42Z">Friday 9 October 2026 at 09:42 UTC</time>'
    '</aside></header>';

String _page(String title, String main) =>
    '<html><head><title>$title</title></head><body>$_header'
    '<main class="_a706">$main</main></body></html>';

String _message(String who, String text, String when) =>
    '<div class="pam _3-95 _2ph- _a6-g uiBoxWhite noborder">'
    '<h2 class="_3-95 _2pim _a6-h _a6-i">$who</h2>'
    '<div class="_3-95 _a6-p"><div><div></div><div>$text</div>'
    '<div></div><div></div></div></div>'
    '<div class="_3-94 _a6-o">$when</div></div>';

String _profile({String name = 'Meera', String bio = 'Chai over coffee'}) =>
    _page(
      'Profile information',
      '<table><tr><td class="_2pin _a6_q">Username<div><div>meera.k</div></div>'
          '</td></tr><tr><td class="_2pin _a6_q">Name<div><div>$name</div></div>'
          '</td></tr><tr><td class="_2pin _a6_q">Bio<div><div>$bio</div></div>'
          '</td></tr><tr><td class="_2pin _a6_q">Phone number<div><div>'
          '+919811100000</div></div></td></tr></table>',
    );

const _a = 'Sep 27, 2026 7:18 am';
const _b = 'Sep 26, 2026 11:05 pm';

String _thread() => _page('Rohan Sharma', [
      _message('Rohan Sharma', 'meera call me at 98111 00000', _a),
      _message('Meera', 'haan bhai pakka 😂😂', _a),
      _message('Meera', 'Rohan bhai yaar', _b),
      _message('Meera', 'You sent an attachment.', _b),
      _message('Meera', 'the 1️⃣ thing', _b),
    ].join());

Archive _zip(Map<String, String> files) {
  final zip = Archive();
  for (final MapEntry(key: name, value: text) in files.entries) {
    final bytes = utf8.encode(text);
    zip.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return zip;
}

const _root = 'instagram-meera-2026-10-09';

void main() {
  test('only the files the server reads, and posts_N in order, never posts.html',
      () {
    final body = InstagramDownload.fromArchive(_zip({
      '$_root/connections/followers_and_following/following.html':
          _page('Following', ''),
      '$_root/your_instagram_activity/media/posts_2.html': _page('Posts', '2'),
      '$_root/your_instagram_activity/media/posts_1.html': _page('Posts', '1'),
      '$_root/your_instagram_activity/media/posts.html':
          _page('Posts', 'Place'),
      '$_root/your_instagram_activity/comments/post_comments_1.html':
          _page('Post comments', ''),
      '$_root/logged_information/recent_searches/word_or_phrase_searches.html':
          _page('Word or phrase searches', ''),
      '$_root/security_and_login_information/login_and_profile_creation/'
              'login_activity.html':
          _page('Login activity', ''),
    }));
    expect(
      body.keys.toSet(),
      {'following', 'posts', 'post_comments'},
    );
    final posts = body['posts']! as List<String>;
    expect(posts.length, 2);
    expect(posts.first, contains('<main class="_a706">1</main>'));
    expect(posts.join(), isNot(contains('Place')));
  });

  test('a zip with none of the files sends nothing at all', () {
    final body = InstagramDownload.fromArchive(_zip({
      '$_root/personal_information/personal_information/'
          'personal_information.html': _profile(),
    }));
    expect(body, isEmpty);
  });

  test('from the messages: when theirs went, and counted words, never a message',
      () {
    final phone = InstagramDownload.fromPhone(
      profile: _profile(),
      threads: [_thread()],
    );
    // Four of hers (the attachment line included), not his.
    expect(phone['dm_sent'], [_a, _b, _b, _b]);
    expect(phone['header'], startsWith('<time datetime="2026-10-09T16:42Z">'));
    // Names, stop words and Instagram's own lines are left out.
    expect(phone['dm_words'], {'bhai': 2, 'haan': 1, 'pakka': 1, 'yaar': 1,
        'thing': 1});
    // A keycap is not an emoji the server takes.
    expect(phone['dm_emoji'], {'😂': 2});
    expect(phone['bio'], 'Chai over coffee');
    final sent = jsonEncode(phone);
    for (final never in ['Rohan', 'rohan', '98111', 'call me', 'attachment',
        '+91', 'meera']) {
      expect(sent, isNot(contains(never)), reason: never);
    }
  });

  test('without the profile file no message is read', () {
    final phone = InstagramDownload.fromPhone(threads: [_thread()]);
    expect(phone, isEmpty);
  });

  test('story times come from the stories file, with its header', () {
    final phone = InstagramDownload.fromPhone(
      stories: _page(
        'Stories',
        '<div class="pam _3-95 _2ph- _a6-g uiBoxWhite noborder">'
            '<div class="_3-94 _a6-o">$_a</div></div>',
      ),
    );
    expect(phone['stories'], [_a]);
    expect(phone['header'], isNotNull);
  });

  test('words are what the server takes: letters only, two to twenty-four', () {
    expect(InstagramDownload.wordsOf('ok see www.x.com/a b2b नमस्ते राम ab'), [
      'ok',
      'see',
      'ab',
    ]);
  });

  test('a line Instagram wrote is not the person', () {
    for (final line in [
      'You sent an attachment.',
      'Meera sent an attachment.',
      'Liked a message',
      'Reacted 😂 to your message',
      'You sent a private reply to a comment on your Instagram post.',
    ]) {
      expect(InstagramDownload.isSystemLine(line), isTrue, reason: line);
    }
    expect(InstagramDownload.isSystemLine('sent you the photos'), isFalse);
  });

  test('entities are read', () {
    expect(InstagramDownload.unescape('Tom &amp; Jerry&#39;s &#x1F602;'),
        "Tom & Jerry's 😂");
  });
}
