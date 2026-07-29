import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import 'brand_mark.dart';

/// The full "arrival" brand moment — [BrandMark] + the shimmering wordmark +
/// a small heraldic divider, optionally with a tagline underneath — at
/// whatever scale a screen needs it. Originally `SplashScreen`'s own private
/// composition; pulled out so its desktop split layout (a large hero-scale
/// lockup on one side) and `AccountScreen`'s desktop layout (a smaller one)
/// can both use the exact same piece instead of two hand-tuned copies
/// drifting apart.
class BrandLockup extends StatefulWidget {
  const BrandLockup({
    super.key,
    this.markSize = 66,
    this.wordmarkFontSize = 40,
    this.tagline,
    this.animated = true,
  });

  final double markSize;
  final double wordmarkFontSize;

  /// `null` omits the tagline line entirely (`AccountScreen`'s smaller
  /// desktop lockup doesn't repeat the splash's own pitch).
  final String? tagline;

  /// `false` skips creating an `AnimationController` at all and freezes the
  /// mark/wordmark mid-gleam — for a screen that doesn't want a second
  /// independent shimmer clock running (or a test that doesn't want to pump
  /// an indefinitely-repeating animation).
  final bool animated;

  @override
  State<BrandLockup> createState() => _BrandLockupState();
}

class _BrandLockupState extends State<BrandLockup> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
        ..repeat();
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

    final markAndWordmark = c == null
        ? [
            BrandMark(size: widget.markSize, filled: false, glow: 0.4),
            const SizedBox(height: AetherSpace.xl),
            _Wordmark(shimmer: 0.3, fontSize: widget.wordmarkFontSize),
          ]
        : [
            AnimatedBuilder(
              animation: c,
              builder: (context, _) => BrandMark(size: widget.markSize, filled: false, glow: c.value),
            ),
            const SizedBox(height: AetherSpace.xl),
            AnimatedBuilder(
              animation: c,
              builder: (context, _) => _Wordmark(shimmer: c.value, fontSize: widget.wordmarkFontSize),
            ),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...markAndWordmark,
        const SizedBox(height: AetherSpace.lg),
        const _OrnamentDivider(),
        if (widget.tagline != null) ...[
          const SizedBox(height: AetherSpace.lg),
          Text(
            widget.tagline!,
            textAlign: TextAlign.center,
            style: AetherType.body.copyWith(
                color: AetherColors.parchmentDim, fontSize: 15, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}

/// The title treatment: a heavy serif slab with a soft ember glow sitting
/// behind it and a slow gold shimmer sweeping across the letterforms — the
/// single most ceremonial element on screen, so it earns its own painter
/// instead of a plain styled [Text].
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.shimmer, required this.fontSize});

  /// 0..1 loop position, reused from [BrandLockup]'s animation so the whole
  /// lockup breathes on one clock instead of several out-of-sync timers.
  final double shimmer;
  final double fontSize;

  static const _text = 'Aetherbook';

  TextStyle get _style => TextStyle(
        fontFamily: 'Marcellus',
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.2,
        color: Colors.white,
      );

  @override
  Widget build(BuildContext context) {
    // The shimmer highlight travels left-to-right and loops; a wide,
    // soft-edged band rather than a hard line so it reads as a gleam, not a
    // scan.
    final sweep = (shimmer * 2.6) - 0.8;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ember glow, blurred well past the glyph edges.
        Text(
          _text,
          style: _style.copyWith(
            color: AetherColors.gold.withValues(alpha: 0.55),
            shadows: [
              Shadow(
                  color: AetherColors.gold.withValues(alpha: 0.6),
                  blurRadius: 28),
            ],
          ),
        ),
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            colors: const [
              AetherColors.goldSoft,
              AetherColors.goldBright,
              Colors.white,
              AetherColors.goldBright,
              AetherColors.goldSoft,
            ],
            stops: [
              (sweep - 0.35).clamp(0.0, 1.0),
              (sweep - 0.12).clamp(0.0, 1.0),
              sweep.clamp(0.0, 1.0),
              (sweep + 0.12).clamp(0.0, 1.0),
              (sweep + 0.35).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: Text(_text, style: _style),
        ),
      ],
    );
  }
}

/// A small heraldic rule under the wordmark — two hairlines flanking a
/// diamond — the kind of flourish that signals "this is a tome", not a form.
class _OrnamentDivider extends StatelessWidget {
  const _OrnamentDivider();

  @override
  Widget build(BuildContext context) {
    Widget line() => Container(
          width: 42,
          height: 1,
          color: AetherColors.hairlineStrong,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AetherColors.gold,
                boxShadow: AetherShadow.glow(AetherColors.gold, strength: 0.6),
              ),
            ),
          ),
        ),
        line(),
      ],
    );
  }
}
