import 'package:aetherbook/app/widgets/home_bottom_nav.dart';
import 'package:aetherbook/app/widgets/home_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeSidebar', () {
    testWidgets('shows every destination, the world list, and the account row', (tester) async {
      HomeNavDestination? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeSidebar(
            current: HomeNavDestination.inicio,
            onSelect: (d) => selected = d,
            worlds: const [
              HomeWorldEntry(name: 'Isekai', accent: Colors.amber, count: 2),
              HomeWorldEntry(name: 'Xianxia', accent: Colors.teal, count: 0),
            ],
            accountInitial: 'F',
            accountName: 'Fernando',
            accountSubtitle: '6 tomos · 89 turnos',
          ),
        ),
      ));

      for (final d in HomeNavDestination.values) {
        expect(find.text(d.label), findsOneWidget);
      }
      expect(find.text('Isekai'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Xianxia'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Fernando'), findsOneWidget);
      expect(find.text('6 tomos · 89 turnos'), findsOneWidget);

      await tester.tap(find.text('Mis historias'));
      expect(selected, HomeNavDestination.misHistorias);
    });
  });

  group('HomeBottomNav', () {
    testWidgets('shows 4 destinations (no Ajustes) and fires onSelect', (tester) async {
      HomeNavDestination? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeBottomNav(
            current: HomeNavDestination.inicio,
            onSelect: (d) => selected = d,
          ),
        ),
      ));

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Mis historias'), findsOneWidget);
      expect(find.text('Explorar'), findsOneWidget);
      expect(find.text('El Códice'), findsOneWidget);
      expect(find.text('Ajustes'), findsNothing);

      await tester.tap(find.text('Explorar'));
      expect(selected, HomeNavDestination.explorar);
    });
  });
}
