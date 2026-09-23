import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';

/// The three networks a person can hand to a match. Nothing is read from any
/// of them: a link is a handle the person typed, shown only to people they are
/// matched with, and only while its switch is on.
enum SocialNetwork {
  instagram('instagram', 'Instagram'),
  x('x', 'X'),
  linkedin('linkedin', 'LinkedIn'),
  unknown('', '');

  const SocialNetwork(this.wire, this.label);

  final String wire;
  final String label;

  static SocialNetwork parse(String? raw) => values.firstWhere(
        (n) => n.wire == raw && n != unknown,
        orElse: () => unknown,
      );

  /// The ones there are, in the order the server and the design list them.
  static const shown = [instagram, x, linkedin];
}

/// One link. Your own carry [handle] and the switch; a match's carry only
/// where it goes, and [shown] is always true, since the server sends nothing
/// that is switched off.
@immutable
class SocialLink {
  const SocialLink({
    required this.network,
    required this.display,
    required this.url,
    this.handle,
    this.shown = true,
  });

  final SocialNetwork network;

  /// "@ananya", or the bare name on LinkedIn.
  final String display;

  /// Always on the network's own domain: the server builds it from the handle,
  /// never from what was pasted.
  final String url;
  final String? handle;
  final bool shown;

  static SocialLink fromJson(Json j) => SocialLink(
        network: SocialNetwork.parse(j.strOrNull('network')),
        display: j.str('display'),
        url: j.str('url'),
        handle: j.strOrNull('handle'),
        shown: j.flag('shown', fallback: true),
      );

  static List<SocialLink> listFrom(List<Json> items) => [
        for (final item in items)
          if (SocialLink.fromJson(item) case final l
              when l.network != SocialNetwork.unknown)
            l,
      ];
}
