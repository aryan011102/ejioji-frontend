import 'package:ejioji/core/theme/tokens.dart';
import 'package:ejioji/features/chats/presentation/in_common/story_ring.dart';
import 'package:ejioji/shared/widgets/identity.dart';
import 'package:ejioji/shared/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Their photo is drawn at the top of a chat before the in common read
/// answers, and every face is decoded small and the same way, so the chats
/// list, the top of the chat and the stories share one cached image.
void main() {
  const url = 'https://example.test/still.jpg?sig=1';

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: Center(child: child)),
      );

  ImageProvider<Object> imageOf(WidgetTester tester) =>
      tester.widget<Image>(find.byType(Image)).image;

  testWidgets('a face is decoded small, not at the size of the still', (tester) async {
    await pump(tester, const Avatar(seedColor: AppColors.fill, imageUrl: url));
    final image = imageOf(tester);
    expect(image, isA<ResizeImage>());
    expect((image as ResizeImage).width, lessThanOrEqualTo(320));
    expect((image.imageProvider as NetworkImage).url, url);
  });

  testWidgets('one cached image whatever size the face is drawn at', (tester) async {
    await pump(tester, const Avatar(seedColor: AppColors.fill, size: 29, imageUrl: url));
    final small = imageOf(tester);
    await pump(tester, const Avatar(seedColor: AppColors.fill, size: 104, imageUrl: url));
    expect(imageOf(tester), small);
  });

  testWidgets('without a ring the photo is there, and takes no tap', (tester) async {
    var taps = 0;
    await pump(
      tester,
      StoryRing(name: 'Asha', ringed: false, imageUrl: url, onTap: () => taps++),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Pressable), findsNothing);
    await tester.tap(find.byType(Avatar));
    expect(taps, 0);
  });

  testWidgets('the ring takes the same space as the photo alone', (tester) async {
    await pump(tester, StoryRing(name: 'Asha', ringed: false, imageUrl: url, onTap: () {}));
    final alone = tester.getSize(find.byType(StoryRing));
    await pump(tester, StoryRing(name: 'Asha', imageUrl: url, onTap: () {}));
    expect(tester.getSize(find.byType(StoryRing)), alone);
    expect(find.byType(Pressable), findsOneWidget);
  });
}
