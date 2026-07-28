import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/world_theme.dart';

/// The ambient backdrop: a deep ink field with a faint etheric glow bleeding
/// from the top, a vignette that draws the eye inward, and a slow drift of
/// glowing motes rising through it — the world feels alive behind the text
/// instead of a static gradient (GDD §9: "makes every screen feel like a
/// place, not a form").
class AetherBackground extends StatefulWidget {
  const AetherBackground({
    super.key,
    required this.child,
    this.particles = true,
    this.accent = AetherColors.gold,
    this.base = AetherColors.ink,
    this.texture,
  });

  final Widget child;

  /// Set `false` for screens that render heavy content of their own (long
  /// scrolling text) where the motion would compete rather than support.
  final bool particles;

  /// Tint for the drifting motes — lets a screen's dominant color (e.g. a
  /// story module's accent, or a world's [WorldTheme.accent]) bleed faintly
  /// into the atmosphere.
  final Color accent;

  /// The backdrop gradient's mid tone (V2 design prototype §4a-4d's per-world
  /// "base" — e.g. `WorldTheme.forWorld(world).base`). Defaults to the app's
  /// single global `AetherColors.ink`, so a screen that never passes this
  /// (every screen predating per-world theming) looks exactly as before —
  /// visible even with [particles] off, unlike [accent].
  final Color base;

  /// Which per-world background treatment (V2 §4a, Stage T) to layer behind
  /// [child] — `null` (the default, and what `radialWarm` itself also
  /// resolves to) renders exactly the original warm radial gradient, so
  /// every screen that predates this — and Isekai, whose declared texture
  /// *is* `radialWarm` — looks byte-identical.
  final WorldTextureKind? texture;

  @override
  State<AetherBackground> createState() => _AetherBackgroundState();
}

class _AetherBackgroundState extends State<AetherBackground>
    with SingleTickerProviderStateMixin {
  // Null (never even created) when `widget.particles` is false
  // (game_screen.dart, codex_screen.dart) — an AnimationController that
  // `..repeat()`s forever but is never painted would still tick in the
  // background for nothing, and an indefinitely-repeating animation never
  // "settles", so it would also hang any pumpAndSettle()-based widget test
  // on that screen. Created in initState, not as a lazy `late final` field
  // default: when it *was* unconditional-but-lazy, its first access ended up
  // happening inside dispose() (nothing in build() touched it when particles
  // was false), which crashes — vsync can't ask a deactivated element for a
  // ticker ("Looking up a deactivated widget's ancestor is unsafe").
  AnimationController? _c;
  List<_Mote> _motes = const [];

  @override
  void initState() {
    super.initState();
    if (widget.particles) {
      _c = AnimationController(vsync: this, duration: const Duration(seconds: 26))
        ..repeat();
      _motes = _seedMotes(widget.accent);
    }
  }

  static List<_Mote> _seedMotes(Color accent) {
    final rng = math.Random(7); // fixed seed: identical layout every launch.
    return List.generate(22, (i) {
      final warm = i.isEven;
      return _Mote(
        x: rng.nextDouble(),
        phase: rng.nextDouble(),
        speed: 0.4 + rng.nextDouble() * 0.9,
        sway: 14 + rng.nextDouble() * 30,
        radius: 1.2 + rng.nextDouble() * 2.4,
        color: warm ? AetherColors.goldBright : accent,
      );
    });
  }

  @override
  void didUpdateWidget(covariant AetherBackground old) {
    super.didUpdateWidget(old);
    if (_c != null && old.accent != widget.accent) {
      _motes = _seedMotes(widget.accent);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final c = _c;
    if (reduceMotion && c != null && c.isAnimating) c.stop();
    final kind = widget.texture;

    return DecoratedBox(
      decoration: _backgroundDecoration(kind, widget.base, widget.accent),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (kind == WorldTextureKind.fog)
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _FogBandsPainter())),
            ),
          if (kind == WorldTextureKind.scanline)
            Positioned.fill(
              child: IgnorePointer(
                  child: CustomPaint(painter: _ScanlinePainter(accent: widget.accent))),
            ),
          if (kind == WorldTextureKind.grain)
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: const _GrainPainter())),
            ),
          if (c != null && !reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: c,
                  builder: (context, _) => CustomPaint(
                    painter: _MoteFieldPainter(t: c.value, motes: _motes),
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

/// The base gradient behind everything else — `null`/`radialWarm`/`fog` all
/// share the app's original warm radial (fog layers its mist bands *on top*
/// via [_FogBandsPainter] rather than replacing the base); `hardDiagonal`,
/// `scanline` and `grain` swap in a plainer directional gradient the other
/// overlays read better against (V2 §4a).
BoxDecoration _backgroundDecoration(WorldTextureKind? kind, Color base, Color accent) {
  switch (kind) {
    case WorldTextureKind.hardDiagonal:
      // ~160°, hard stops instead of a soft blend — Superhéroes reads like a
      // comic-panel duotone rather than an atmospheric wash.
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          transform: GradientRotation(160 * math.pi / 180),
          colors: [
            Color.lerp(base, accent, 0.22) ?? base,
            Color.lerp(base, accent, 0.22) ?? base,
            base,
            AetherColors.void_,
          ],
          stops: const [0.0, 0.4, 0.4, 1.0],
        ),
      );
    case WorldTextureKind.scanline:
    case WorldTextureKind.grain:
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(base, accent, 0.12) ?? base,
            base,
            AetherColors.void_,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      );
    case WorldTextureKind.radialWarm:
    case WorldTextureKind.fog:
    case null:
      return BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.1),
          radius: 1.5,
          // The warm top highlight leans slightly toward `accent` on top of
          // `base` — for the default gold/ink pair this reproduces the
          // original hardcoded `Color(0xFF201A13)` almost exactly; a themed
          // world's own base/accent carry through instead. The deepest
          // anchor (`void_`) stays constant across every world by design
          // (V2 prototype §4a: "el resto del sistema... no se mueve").
          colors: [
            Color.lerp(base, accent, 0.12) ?? base,
            base,
            AetherColors.void_,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      );
  }
}

class _Mote {
  _Mote({
    required this.x,
    required this.phase,
    required this.speed,
    required this.sway,
    required this.radius,
    required this.color,
  });

  /// Horizontal anchor, 0..1 of the canvas width.
  final double x;

  /// Where in its rise this mote starts, 0..1 — staggers the field so motes
  /// don't all launch from the bottom edge together.
  final double phase;

  /// Relative rise speed (some drift slower than others).
  final double speed;

  /// Amplitude, in logical pixels, of the side-to-side sway.
  final double sway;
  final double radius;
  final Color color;
}

/// Xianxia's `fog` texture (V2 §4a): a few faint, heavily-blurred pale bands
/// layered over the base radial — static (no animation), reads as mist
/// sitting at fixed heights rather than motion.
class _FogBandsPainter extends CustomPainter {
  const _FogBandsPainter();

  static const _bandCenters = [0.28, 0.5, 0.74];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE6E9DE).withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46);
    for (final center in _bandCenters) {
      final y = size.height * center;
      final band = Rect.fromLTWH(-40, y - size.height * 0.05, size.width + 80, size.height * 0.1);
      canvas.drawRect(band, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FogBandsPainter oldDelegate) => false;
}

/// Cyberpunk's `scanline` texture (V2 §4a): thin repeating horizontal lines
/// in the world's accent color, low-alpha — there is no `BoxDecoration`
/// equivalent of CSS's `repeating-linear-gradient`, so this paints them by
/// hand instead.
class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accent.withValues(alpha: 0.05);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Post-apocalíptico's `grain` texture (V2 §4a): scattered semi-transparent
/// dots, fixed seed — static noise, no shine and no motion, unlike the
/// drifting motes it shares the stack with.
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(11);
    final paint = Paint();
    for (var i = 0; i < 160; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final radius = 0.4 + rng.nextDouble() * 1.1;
      paint.color = Colors.white.withValues(alpha: 0.03 + rng.nextDouble() * 0.04);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}

/// Paints a slow upward drift of soft glowing motes — embers rising off the
/// world underneath the page. Deliberately sparse and low-alpha: atmosphere,
/// not decoration that competes with the foreground text.
class _MoteFieldPainter extends CustomPainter {
  _MoteFieldPainter({required this.t, required this.motes});

  final double t;
  final List<_Mote> motes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final mote in motes) {
      final rise = (t * mote.speed + mote.phase) % 1.0;
      final y = size.height * (1.0 - rise);
      final sway = math.sin((rise + mote.phase) * 2 * math.pi) * mote.sway;
      final dx = mote.x * size.width + sway;
      // Fade in near the bottom, fade out near the top — never a hard pop.
      final edgeFade = (1 - (rise * 2 - 1).abs()).clamp(0.0, 1.0);
      final alpha = edgeFade * 0.45;
      if (alpha <= 0.01) continue;
      canvas.drawCircle(
        Offset(dx, y),
        mote.radius,
        Paint()
          ..color = mote.color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
  }

  @override
  bool shouldRepaint(_MoteFieldPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.motes != motes;
}

/// The "el destino se escribe…" indicator (GDD §9: never a frozen screen).
/// Three glowing motes pulse in sequence while the AI narrates.
class DestinyWriting extends StatefulWidget {
  const DestinyWriting({super.key, this.label = 'El destino se escribe'});

  final String label;

  @override
  State<DestinyWriting> createState() => _DestinyWritingState();
}

class _DestinyWritingState extends State<DestinyWriting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (_c.value - i * 0.18) % 1.0;
              final glow = (0.4 + 0.6 * (1 - (phase * 2 - 1).abs()))
                  .clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AetherColors.gold.withValues(alpha: glow),
                    boxShadow: AetherShadow.glow(AetherColors.gold,
                        strength: glow * 0.6),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: AetherSpace.md),
        Text('${widget.label}…',
            style: AetherType.caption
                .copyWith(color: AetherColors.goldSoft, fontSize: 14)),
      ],
    );
  }
}

/// A celebratory banner shown when the character advances a level/realm.
class LevelUpBanner extends StatelessWidget {
  const LevelUpBanner({
    super.key,
    required this.levelsGained,
    this.unitLabel = 'nivel',
  });

  final int levelsGained;

  /// The world's term for a level (e.g. 'reino'), so the banner reads right
  /// whatever the story's progression is called.
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    // Naive plural: good enough for 'reino'→'reinos', 'nivel'→'niveles'…
    final plural = unitLabel.endsWith('l') ? '${unitLabel}es' : '${unitLabel}s';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AetherSpace.md, vertical: AetherSpace.sm),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AetherColors.goldGlow, Color(0x11EAC978)],
        ),
        borderRadius: AetherRadius.allPill,
        border: Border.all(color: AetherColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome,
              size: 15, color: AetherColors.goldBright),
          const SizedBox(width: AetherSpace.sm),
          Text(
            levelsGained > 1
                ? 'Has ascendido $levelsGained $plural'
                : 'Has ascendido de $unitLabel',
            style: AetherType.caption.copyWith(
                color: AetherColors.goldSoft, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
