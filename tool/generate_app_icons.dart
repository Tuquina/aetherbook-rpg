// One-off generator for the app's web icon/favicon assets (V2 §7a/§7b) —
// there is no exported image of the brand mark anywhere (not in this repo,
// not in the design handoff: §7's "icono de aplicación" is the same
// clip-path hexagon drawn in CSS, matching `lib/app/widgets/brand_mark.dart`
// exactly). This renders that same widget through the Flutter test harness
// (RenderRepaintBoundary -> PNG) instead of hand-authoring a separate SVG.
//
// Run once with:
//   ./tool/flutter.sh test tool/generate_app_icons.dart
// Re-run only if the brand mark's colors/geometry ever change.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aetherbook/app/design/tokens.dart';
import 'package:aetherbook/app/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadMarcellus() async {
  final data = await File('assets/fonts/Marcellus-Regular.ttf').readAsBytes();
  final loader = FontLoader('Marcellus')
    ..addFont(Future.value(ByteData.view(data.buffer, data.offsetInBytes, data.length)));
  await loader.load();
}

Future<void> _capture(
  WidgetTester tester, {
  required String path,
  required double canvasSize,
  required double hexFraction,
}) async {
  // The test harness's root render view imposes *tight* constraints on
  // whatever `pumpWidget` renders, sized to `tester.view.physicalSize` (the
  // 800x600 default, unless overridden) — the `Container(width: canvasSize,
  // height: canvasSize)` below only controls what IT hands its own child,
  // not the size the harness forces on it as the top-level render object.
  // Without this, every capture (regardless of the requested `canvasSize`)
  // came out 800x600 with the hexagon shrunk to a speck in the middle —
  // confirmed on disk (`file web/favicon.png` etc.) and exactly why the
  // deployed favicon read as a plain dark square in the browser tab.
  tester.view.physicalSize = Size(canvasSize, canvasSize);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Container(
          width: canvasSize,
          height: canvasSize,
          color: AetherColors.ink,
          child: Center(
            child: BrandMark(size: canvasSize * hexFraction),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(byteData!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $path (${canvasSize.toInt()}x${canvasSize.toInt()})');
}

void main() {
  testWidgets('generate app icons from BrandMark', (tester) async {
    await tester.runAsync(() async {
      await _loadMarcellus();

      // Regular icons: the hexagon fills most of the canvas, matching how
      // BrandMark is used everywhere else in the app.
      await _capture(tester,
          path: 'web/favicon.png', canvasSize: 32, hexFraction: 0.82);
      await _capture(tester,
          path: 'web/icons/Icon-192.png', canvasSize: 192, hexFraction: 0.82);
      await _capture(tester,
          path: 'web/icons/Icon-512.png', canvasSize: 512, hexFraction: 0.82);

      // Maskable icons: kept inside the safe zone (PWA spec: the inner ~40%
      // radius / ~66% diameter) so a circular or rounded-square OS mask never
      // clips the hexagon -- V2 §7b: "el hexágono va contenido dentro del
      // recorte del sistema operativo, nunca recortado por él".
      await _capture(tester,
          path: 'web/icons/Icon-maskable-192.png', canvasSize: 192, hexFraction: 0.55);
      await _capture(tester,
          path: 'web/icons/Icon-maskable-512.png', canvasSize: 512, hexFraction: 0.55);
    });
  });
}
