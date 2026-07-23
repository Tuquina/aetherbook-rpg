import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/engine/action_resolution.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The "Tirada del Destino" — an animated reveal of a resolved action
/// (GDD §4.4). It makes the mechanics *legible and dramatic*: a d20 tumbles
/// and lands, the equation `atributo + d20 = total` builds up, and a band
/// meter shows exactly where the total fell relative to the difficulty and
/// the critical threshold — so the player sees how their attributes and the
/// roll combined to bend the story.
///
/// Pass a fresh [Key] (e.g. keyed on the resolution) so a new roll replays.
class FateRoll extends StatefulWidget {
  const FateRoll({
    super.key,
    required this.resolution,
    this.criticalMargin = 5,
  });

  final ActionResolution resolution;

  /// The world's critical margin, so the meter's crit tick is accurate. The
  /// engine already did the authoritative banding; this is display only.
  final int criticalMargin;

  @override
  State<FateRoll> createState() => _FateRollState();
}

class _FateRollState extends State<FateRoll>
    with SingleTickerProviderStateMixin {
  static const double _landFraction = 0.42;

  late final AnimationController _c;
  late final List<int> _tumble;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.resolution.roll * 7 + 13);
    _tumble = List.generate(14, (_) => 1 + rng.nextInt(20));
    _c = AnimationController(vsync: this, duration: AetherMotion.roll)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color get _bandColor => switch (widget.resolution.outcome) {
        ActionOutcome.criticalSuccess => AetherColors.critical,
        ActionOutcome.success => AetherColors.success,
        ActionOutcome.failure => AetherColors.failure,
      };

  String get _bandLabel => switch (widget.resolution.outcome) {
        ActionOutcome.criticalSuccess => 'Éxito crítico',
        ActionOutcome.success => 'Éxito',
        ActionOutcome.failure => 'Falla',
      };

  int _displayedRoll(double t) {
    if (t >= _landFraction) return widget.resolution.roll;
    final idx = (t / _landFraction * _tumble.length)
        .floor()
        .clamp(0, _tumble.length - 1);
    return _tumble[idx];
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resolution;
    final band = _bandColor;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final settleT = (t / _landFraction).clamp(0.0, 1.0);
        final equationT = _phase(t, 0.42, 0.62);
        final meterT = _phase(t, 0.55, 0.92);
        final labelT = _phase(t, 0.74, 1.0);

        return Container(
          padding: const EdgeInsets.fromLTRB(
              AetherSpace.lg, AetherSpace.lg, AetherSpace.lg, AetherSpace.md),
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allLg,
            border: Border.all(color: band.withValues(alpha: 0.35)),
            boxShadow: AetherShadow.glow(band, strength: 0.12 + 0.12 * labelT),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Die(
                    number: _displayedRoll(t),
                    settle: settleT,
                    color: band,
                    landed: t >= _landFraction,
                  ),
                  const SizedBox(width: AetherSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('CHEQUEO DE ${r.attributeKey.toUpperCase()}',
                            style: AetherType.overline),
                        const SizedBox(height: AetherSpace.sm),
                        Opacity(
                          opacity: equationT,
                          child: _Equation(resolution: r),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AetherSpace.lg),
              _BandMeter(
                resolution: r,
                criticalMargin: widget.criticalMargin,
                progress: meterT,
                band: band,
              ),
              const SizedBox(height: AetherSpace.md),
              Opacity(
                opacity: labelT,
                child: Transform.translate(
                  offset: Offset(0, (1 - labelT) * 6),
                  child: _OutcomeLabel(
                    label: _bandLabel,
                    color: band,
                    resolution: r,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Maps global time [t] into a 0..1 progress for a sub-phase [start, end].
  double _phase(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);
}

// ── The d20 die ───────────────────────────────────────────────────────────

class _Die extends StatelessWidget {
  const _Die({
    required this.number,
    required this.settle,
    required this.color,
    required this.landed,
  });

  final int number;
  final double settle;
  final Color color;
  final bool landed;

  @override
  Widget build(BuildContext context) {
    // Overshoot scale-in, and a decaying wobble while tumbling.
    final scale = 0.6 + Curves.easeOutBack.transform(settle) * 0.4;
    final wobble = landed ? 0.0 : math.sin(settle * math.pi * 5) * 0.18;

    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: wobble,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow:
                landed ? AetherShadow.glow(color, strength: 0.45) : const [],
          ),
          child: CustomPaint(
            painter: _D20Painter(color: color),
            child: Center(
              child: Text(
                '$number',
                style: AetherType.numeral.copyWith(
                  fontSize: 24,
                  color: landed ? color : AetherColors.parchment,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a face-on d20 silhouette: a pointy-top hexagon with an inner
/// triangle and facet lines, filled with a subtle metallic gradient.
class _D20Painter extends CustomPainter {
  const _D20Painter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;

    final hex = _polygon(center, radius, 6, -math.pi / 2);
    final tri = _polygon(center, radius * 0.52, 3, -math.pi / 2);

    // Body gradient.
    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AetherColors.surfaceRaised, AetherColors.void_],
      ).createShader(Offset.zero & size);
    canvas.drawPath(_pathOf(hex), body);

    // Facet shading: connect hex edges to the triangle for a gem look.
    for (var i = 0; i < 6; i++) {
      final a = hex[i];
      final b = hex[(i + 1) % 6];
      final t = tri[(i ~/ 2) % 3];
      final alpha = i.isEven ? 0.10 : 0.05;
      canvas.drawPath(
          _pathOf([a, b, t]), Paint()..color = color.withValues(alpha: alpha));
    }

    // Edges.
    canvas.drawPath(
      _pathOf(hex),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.85),
    );
    canvas.drawPath(
      _pathOf(tri),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = color.withValues(alpha: 0.45),
    );
  }

  List<Offset> _polygon(Offset c, double r, int sides, double startAngle) => [
        for (var i = 0; i < sides; i++)
          Offset(
            c.dx + r * math.cos(startAngle + i * 2 * math.pi / sides),
            c.dy + r * math.sin(startAngle + i * 2 * math.pi / sides),
          ),
      ];

  Path _pathOf(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_D20Painter oldDelegate) => oldDelegate.color != color;
}

// ── The equation ──────────────────────────────────────────────────────────

class _Equation extends StatelessWidget {
  const _Equation({required this.resolution});

  final ActionResolution resolution;

  @override
  Widget build(BuildContext context) {
    final r = resolution;
    return Wrap(
      spacing: AetherSpace.xs,
      runSpacing: AetherSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _tile('${r.attribute}', r.attributeKey),
        if (r.modifiers != 0) ...[
          _op(r.modifiers > 0 ? '+' : '−'),
          _tile('${r.modifiers.abs()}', 'mod'),
        ],
        _op('+'),
        _tile('${r.roll}', 'd20'),
        _op('='),
        _tile('${r.total}', 'total', emphasized: true),
      ],
    );
  }

  Widget _op(String s) => Text(s,
      style: AetherType.caption
          .copyWith(fontSize: 15, color: AetherColors.parchmentFaint));

  Widget _tile(String value, String label, {bool emphasized = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasized ? AetherColors.goldGlow : AetherColors.surfaceRaised,
        borderRadius: AetherRadius.allSm,
        border: Border.all(
          color: emphasized ? AetherColors.gold : AetherColors.hairline,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    emphasized ? AetherColors.goldSoft : AetherColors.parchment,
              )),
          Text(label,
              style: const TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 0.5,
                  color: AetherColors.parchmentFaint)),
        ],
      ),
    );
  }
}

// ── The band meter ────────────────────────────────────────────────────────

class _BandMeter extends StatelessWidget {
  const _BandMeter({
    required this.resolution,
    required this.criticalMargin,
    required this.progress,
    required this.band,
  });

  final ActionResolution resolution;
  final int criticalMargin;
  final double progress;
  final Color band;

  @override
  Widget build(BuildContext context) {
    final r = resolution;
    // The domain is every total this check could have produced: base + 1..20.
    final base = r.attribute + r.modifiers;
    final domainMin = base + 1;
    final domainMax = base + 20;
    final span = (domainMax - domainMin).clamp(1, 1 << 30);

    double frac(int x) => ((x - domainMin) / span).clamp(0.0, 1.0);
    final successFrac = frac(r.difficulty);
    final critFrac = frac(r.difficulty + criticalMargin);
    final totalFrac = frac(r.total);

    final failFlex = (successFrac * 1000).round();
    final succFlex =
        ((critFrac - successFrac).clamp(0.0, 1.0) * 1000).round();
    final critFlex = ((1 - critFrac).clamp(0.0, 1.0) * 1000).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final markerX = (totalFrac * progress) * width;
            return SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: AetherRadius.allPill,
                    child: Row(children: [
                      _zone(failFlex, AetherColors.failureDim),
                      _zone(succFlex, AetherColors.successDim),
                      _zone(critFlex, AetherColors.criticalDim),
                    ]),
                  ),
                  Positioned(
                    left: (markerX - 2).clamp(0.0, width - 4),
                    top: -3,
                    bottom: -3,
                    child: Opacity(
                      opacity: progress,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: band,
                          borderRadius: AetherRadius.allPill,
                          boxShadow: AetherShadow.glow(band, strength: 0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AetherSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _legend('Falla', AetherColors.failure),
            _legend('Éxito', AetherColors.success),
            _legend('Crítico', AetherColors.critical),
          ],
        ),
      ],
    );
  }

  Widget _zone(int flex, Color color) => Expanded(
        flex: flex == 0 ? 1 : flex,
        child: Container(color: flex == 0 ? Colors.transparent : color),
      );

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: color, borderRadius: AetherRadius.allPill)),
          const SizedBox(width: 5),
          Text(label, style: AetherType.overline.copyWith(fontSize: 10)),
        ],
      );
}

// ── The outcome label ─────────────────────────────────────────────────────

class _OutcomeLabel extends StatelessWidget {
  const _OutcomeLabel({
    required this.label,
    required this.color,
    required this.resolution,
  });

  final String label;
  final Color color;
  final ActionResolution resolution;

  @override
  Widget build(BuildContext context) {
    final natNote = resolution.isNatural20
        ? '¡20 natural!'
        : resolution.isNatural1
            ? '1 natural'
            : null;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: AetherRadius.allPill,
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(width: AetherSpace.md),
        Text('vs dificultad ${resolution.difficulty}',
            style: AetherType.caption),
        if (natNote != null) ...[
          const Spacer(),
          Text(natNote,
              style: AetherType.caption
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}
