import 'package:ejioji/core/session/session.dart';
import 'package:ejioji/data/providers.dart';
import 'package:ejioji/features/account/presentation/account_page.dart';
import 'package:ejioji/shared/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A signed-in session without reading a stored token.
class _Session extends SessionController {
  @override
  Session build() => const Session();
}

MyProfile _me({required bool verified}) => MyProfile.fromJson({
      'profile': {
        'first_name': 'Pritika',
        'last_name': 'Rao',
        'birth_date': '1999-04-02',
        'age': 27,
        'gender': 'woman',
        'city': 'delhi_ncr',
      },
      'photos': <Object>[],
      'tiles': <Object>[],
      'publish': {'published': true, 'visible': true, 'blocking': <Object>[]},
      'verified': verified,
    });

Future<void> _open(WidgetTester tester, MyProfile me) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        myProfileProvider.overrideWith((_) async => me),
      ],
      child: const MaterialApp(home: AccountPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tickBy(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.verified),
    );

void main() {
  testWidgets('a verified person sees the tick beside their name',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, _me(verified: true));
    expect(_tickBy('Pritika Rao'), findsOneWidget);
    // Read out, not only drawn: the card is one tappable row, so the tick is
    // read as part of its label, after the name.
    expect(find.bySemanticsLabel(RegExp(r'Pritika Rao\s+Verified')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('nobody else does', (tester) async {
    await _open(tester, _me(verified: false));
    expect(find.text('Pritika Rao'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsNothing);
  });
}
