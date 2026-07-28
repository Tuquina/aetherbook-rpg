import 'package:aetherbook/app/widgets/library_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LibraryThumbnail', () {
    testWidgets('renders the scene image when imageUrl is set', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LibraryThumbnail(
          imageUrl: 'https://cdn.aetherbook.dev/scene-images/abc.png',
          accent: Colors.amber,
        ),
      ));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('falls back to an accent-tinted gradient when imageUrl is null', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LibraryThumbnail(imageUrl: null, accent: Colors.amber),
      ));
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('clips to the given size', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LibraryThumbnail(imageUrl: null, accent: Colors.amber, size: 60),
      ));
      await tester.pump();

      final box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(box.width, 60);
      expect(box.height, 60);
    });
  });
}
