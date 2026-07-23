import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'widgets/atmosphere.dart';

/// The entry screen: an animated tome, the wordmark, and the way in. A moment
/// of arrival before the world opens (GDD §9). Account sign-in is stubbed for
/// now (anonymous play happens transparently) — the affordance is here so it
/// can light up later without a redesign.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _begin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        pageBuilder: (_, _, _) => GameScreen(controller: widget.controller),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _accountSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AetherColors.surfaceRaised,
        content: Text('Pronto vas a poder guardar tu progreso con tu cuenta.',
            style: TextStyle(color: AetherColors.parchment)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Respect the OS "reduce motion" preference: hold the tome open, still.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _c.isAnimating) _c.stop();

    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(AetherSpace.xl),
                child: _EntranceFade(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      SizedBox(
                        height: 170,
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) => CustomPaint(
                            painter: _TomePainter(t: _c.value),
                            size: const Size(220, 170),
                          ),
                        ),
                      ),
                      const SizedBox(height: AetherSpace.xl),
                      _Wordmark(),
                      const SizedBox(height: AetherSpace.md),
                      Text(
                        'Un multiverso que se escribe con vos',
                        textAlign: TextAlign.center,
                        style: AetherType.body.copyWith(
                            color: AetherColors.parchmentDim, fontSize: 15),
                      ),
                      const Spacer(flex: 3),
                      _PrimaryButton(label: 'Comenzar', onTap: _begin),
                      const SizedBox(height: AetherSpace.md),
                      TextButton(
                        onPressed: _accountSoon,
                        child: Text('Entrar con tu cuenta',
                            style: AetherType.caption.copyWith(
                                color: AetherColors.parchmentFaint,
                                fontSize: 13)),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Wordmark ──────────────────────────────────────────────────────────────

class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [AetherColors.gold, AetherColors.goldBright, AetherColors.gold],
        stops: [0, 0.5, 1],
      ).createShader(rect),
      child: const Text(
        'AETHERBOOK',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 38,
          fontWeight: FontWeight.w700,
          letterSpacing: 4,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Primary button ──────────────────────────────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AetherMotion.fast,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AetherSpace.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AetherColors.gold, AetherColors.goldBright]),
            borderRadius: AetherRadius.allMd,
            boxShadow: AetherShadow.glow(AetherColors.gold, strength: 0.35),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AetherColors.void_,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Entrance fade ───────────────────────────────────────────────────────────

class _EntranceFade extends StatelessWidget {
  const _EntranceFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: AetherMotion.standard,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: child,
    );
  }
}

// ── The animated tome ───────────────────────────────────────────────────────

/// Paints an open book seen slightly from above, with one page perpetually
/// turning from the right leaf to the left, the whole thing floating.
class _TomePainter extends CustomPainter {
  _TomePainter({required this.t});

  /// Global loop time 0..1.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final float = math.sin(t * 2 * math.pi) * 5;
    canvas.translate(0, float);

    // Glow behind the book.
    canvas.drawCircle(
      Offset(cx, size.height * 0.55),
      size.width * 0.42,
      Paint()
        ..color = AetherColors.gold.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );

    // Spine points.
    final spineTop = Offset(cx, 26);
    final spineBottom = Offset(cx, 118);

    // Static leaves.
    final leftOuterTop = Offset(cx - 88, 38);
    final leftOuterBottom = Offset(cx - 80, 126);
    final rightOuterTop = Offset(cx + 88, 38);
    final rightOuterBottom = Offset(cx + 80, 126);

    _leaf(canvas, [spineTop, leftOuterTop, leftOuterBottom, spineBottom],
        lines: true, mirror: false, cx: cx);
    _leaf(canvas, [spineTop, rightOuterTop, rightOuterBottom, spineBottom],
        lines: true, mirror: true, cx: cx);

    // Turning page: a page turn happens in the first ~40% of the loop.
    final turn = (t / 0.4).clamp(0.0, 1.0);
    if (turn > 0 && turn < 1) {
      final lift = math.sin(turn * math.pi);
      final outerTop = Offset.lerp(rightOuterTop, leftOuterTop, turn)!
          .translate(0, -lift * 26);
      final outerBottom = Offset.lerp(rightOuterBottom, leftOuterBottom, turn)!
          .translate(0, -lift * 20);
      final page = [spineTop, outerTop, outerBottom, spineBottom];

      // Shade the lifting page a touch brighter, catching the light.
      canvas.drawPath(
        _pathOf(page),
        Paint()..color = AetherColors.parchment.withValues(alpha: 0.10 + 0.10 * lift),
      );
      canvas.drawPath(
        _pathOf(page),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round
          ..color = AetherColors.goldBright.withValues(alpha: 0.9),
      );
    }

    // The spine, drawn last so it sits on top.
    canvas.drawLine(
      spineTop,
      spineBottom,
      Paint()
        ..strokeWidth = 2
        ..color = AetherColors.gold.withValues(alpha: 0.9),
    );
  }

  void _leaf(Canvas canvas, List<Offset> pts,
      {required bool lines, required bool mirror, required double cx}) {
    canvas.drawPath(
        _pathOf(pts), Paint()..color = AetherColors.surface.withValues(alpha: 0.9));
    canvas.drawPath(
      _pathOf(pts),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = AetherColors.gold.withValues(alpha: 0.7),
    );
    if (lines) {
      final linePaint = Paint()
        ..strokeWidth = 1
        ..color = AetherColors.gold.withValues(alpha: 0.22);
      for (var i = 0; i < 4; i++) {
        final y = 52.0 + i * 15;
        final innerX = cx + (mirror ? 10 : -10);
        final outerX = cx + (mirror ? 66 : -66);
        canvas.drawLine(Offset(innerX, y), Offset(outerX, y - 2), linePaint);
      }
    }
  }

  Path _pathOf(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_TomePainter oldDelegate) => oldDelegate.t != t;
}
