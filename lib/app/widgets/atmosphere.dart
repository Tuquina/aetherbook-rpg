import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// The ambient backdrop: a deep ink field with a faint etheric glow bleeding
/// from the top, and a vignette that draws the eye inward. Makes every screen
/// feel like a place, not a form (GDD §9).
class AetherBackground extends StatelessWidget {
  const AetherBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.5,
          colors: [Color(0xFF201A13), AetherColors.ink, AetherColors.void_],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: child,
    );
  }
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
  const LevelUpBanner({super.key, required this.levelsGained});

  final int levelsGained;

  @override
  Widget build(BuildContext context) {
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
          const Icon(Icons.auto_awesome, size: 15, color: AetherColors.goldBright),
          const SizedBox(width: AetherSpace.sm),
          Text(
            levelsGained > 1
                ? 'Has ascendido $levelsGained reinos'
                : 'Has ascendido de reino',
            style: AetherType.caption.copyWith(
                color: AetherColors.goldSoft, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
