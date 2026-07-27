import 'package:aetherbook/app/widgets/confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen whose single button opens the sheet and records the result, so
/// tests can assert on what `showConfirmSheet` resolved to without needing
/// their own `Navigator`/context plumbing.
class _Harness extends StatefulWidget {
  const _Harness({this.destructive = true});

  final bool destructive;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool? _result;

  Future<void> _open() async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Cerrar el tomo',
      message: 'Se borran los turnos de esta historia. No se puede deshacer.',
      confirmLabel: 'Sí, abandonar',
      destructive: widget.destructive,
    );
    setState(() => _result = confirmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(onPressed: _open, child: const Text('Abrir')),
          Text('resultado: ${_result?.toString() ?? 'ninguno'}'),
        ],
      ),
    );
  }
}

void main() {
  group('showConfirmSheet', () {
    testWidgets('shows the title, message and both actions', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _Harness()));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Cerrar el tomo'), findsOneWidget);
      expect(find.textContaining('No se puede deshacer'), findsOneWidget);
      expect(find.text('Sí, abandonar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('resolves true when the confirm action is tapped', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _Harness()));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sí, abandonar'));
      await tester.pumpAndSettle();

      expect(find.text('resultado: true'), findsOneWidget);
    });

    testWidgets('resolves false when cancel is tapped', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _Harness()));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('resultado: false'), findsOneWidget);
    });

    testWidgets('resolves false when dismissed by tapping the barrier',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _Harness()));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Tap far above the sheet, on the barrier.
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      expect(find.text('resultado: false'), findsOneWidget);
    });

    testWidgets('uses the gold accent instead of failure red when '
        'destructive: false', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _Harness(destructive: false)));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      final confirmText = tester.widget<Text>(find.text('Sí, abandonar'));
      // AetherColors.gold, not AetherColors.failure — a narrow but direct
      // check that the `destructive` flag actually changes styling.
      expect(confirmText.style?.color, const Color(0xFFC9A24B));
    });
  });
}
