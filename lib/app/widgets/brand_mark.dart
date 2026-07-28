import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// The Aetherbook symbol (V2 design prototype §10a/§10b/§7a): a hexagon —
/// the d20 the fate system rolls — with an open-page "A" inside it. The one
/// brand mark used everywhere the app shows an identity, replacing both the
/// splash screen's old animated tome and any placeholder `Icon` a screen used
/// before this existed (`account_screen.dart`'s `shield_moon_rounded`, most
/// notably — never a real brand element to begin with).
///
/// Two treatments, matching the prototype's own two contexts:
/// - [filled] false (default) — the splash's ceremonial version: a subtle
///   gradient fill, a bright-to-dim gold gradient border, and a thin
///   vertical "spine" line splitting the hexagon like an open book.
/// - [filled] true — the compact version used inline elsewhere (headers,
///   `AccountScreen`): a flat solid gold hexagon with a dark "A", no border
///   or spine.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44, this.filled = true, this.glow = 1.0});

  final double size;
  final bool filled;

  /// 0..1 — only meaningful when [filled] is false. Modulates the border
  /// and glow intensity so the splash screen can tie it to its existing
  /// shimmer clock (itself already reduce-motion aware) instead of this
  /// widget needing its own animation controller.
  final double glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(filled: filled, glow: glow.clamp(0.0, 1.0)),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.03),
            child: Text(
              'A',
              style: TextStyle(
                fontFamily: 'Marcellus',
                fontSize: size * 0.52,
                color: filled ? AetherColors.ink : AetherColors.goldBright,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.filled, required this.glow});

  final bool filled;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final hex = _hexagonPath(center, size);

    if (filled) {
      canvas.drawPath(hex, Paint()..color = AetherColors.goldBright);
      return;
    }

    canvas.drawPath(
      hex,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF33291B), Color(0x990E0C0B)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AetherColors.goldBright.withValues(alpha: 0.45 + 0.4 * glow),
            AetherColors.goldBright.withValues(alpha: 0.12 + 0.08 * glow),
          ],
        ).createShader(Offset.zero & size),
    );

    // The "spine" — a thin vertical split, top-16%..bottom-16% of the hex.
    canvas.drawLine(
      Offset(center.dx, size.height * 0.16),
      Offset(center.dx, size.height * 0.84),
      Paint()
        ..strokeWidth = 1
        ..color = AetherColors.void_.withValues(alpha: 0.5),
    );
  }

  /// Matches the prototype's exact CSS
  /// `clip-path: polygon(50% 0%,100% 25%,100% 75%,50% 100%,0% 75%,0% 25%)` —
  /// a hexagon stretched to touch all four edges of its bounding box, not a
  /// regular (equilateral) one. That means the horizontal and vertical
  /// radii differ: the pointy top/bottom vertices reach the full half-height,
  /// but the flat-side vertices (at ±30°) need `rx = halfWidth / cos(30°)`
  /// to still land exactly on the left/right edges once that angle's cosine
  /// is applied.
  Path _hexagonPath(Offset center, Size size) {
    final ry = size.height / 2;
    final rx = size.width / 2 / math.cos(math.pi / 6);
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final point = Offset(
        center.dx + rx * math.cos(angle),
        center.dy + ry * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.filled != filled || oldDelegate.glow != glow;
}
