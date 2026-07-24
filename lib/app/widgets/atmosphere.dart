import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

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
  });

  final Widget child;

  /// Set `false` for screens that render heavy content of their own (long
  /// scrolling text) where the motion would compete rather than support.
  final bool particles;

  /// Tint for the drifting motes — lets a screen's dominant color (e.g. a
  /// story module's accent) bleed faintly into the atmosphere.
  final Color accent;

  @override
  State<AetherBackground> createState() => _AetherBackgroundState();
}

class _AetherBackgroundState extends State<AetherBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  late List<_Mote> _motes = _seedMotes(widget.accent);

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
    if (old.accent != widget.accent) _motes = _seedMotes(widget.accent);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _c.isAnimating) _c.stop();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.5,
          colors: [Color(0xFF201A13), AetherColors.ink, AetherColors.void_],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.particles && !reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    painter: _MoteFieldPainter(t: _c.value, motes: _motes),
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
