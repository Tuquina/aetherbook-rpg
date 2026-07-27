import 'package:aetherbook/app/widgets/choice_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChoiceCard', () {
    testWidgets('spells out its 1-based index as a Roman numeral',
        (tester) async {
      Future<void> pumpIndex(int index) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: ChoiceCard(index: index, label: 'Opción', onTap: () {}),
            ),
          ));

      await pumpIndex(1);
      expect(find.text('I'), findsOneWidget);

      await pumpIndex(2);
      expect(find.text('II'), findsOneWidget);

      await pumpIndex(4);
      expect(find.text('IV'), findsOneWidget);

      await pumpIndex(9);
      expect(find.text('IX'), findsOneWidget);

      await pumpIndex(40);
      expect(find.text('XL'), findsOneWidget);
    });

    testWidgets('shows its label and calls onTap when pressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChoiceCard(
            index: 1,
            label: 'Forzar el paso con tu chi',
            onTap: () => tapped = true,
          ),
        ),
      ));

      expect(find.text('Forzar el paso con tu chi'), findsOneWidget);

      await tester.tap(find.text('Forzar el paso con tu chi'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
