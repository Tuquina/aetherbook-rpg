import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// Roman-numeral pairs in descending value, used by [_toRoman] — the
/// standard subtractive-notation table (GDD/V2 prototype §1a: "cartas
/// numeradas en romano que suben desde el pie").
const List<(int, String)> _romanNumerals = [
  (1000, 'M'),
  (900, 'CM'),
  (500, 'D'),
  (400, 'CD'),
  (100, 'C'),
  (90, 'XC'),
  (50, 'L'),
  (40, 'XL'),
  (10, 'X'),
  (9, 'IX'),
  (5, 'V'),
  (4, 'IV'),
  (1, 'I'),
];

/// Converts a positive integer to its Roman-numeral spelling (1 -> "I",
/// 4 -> "IV", 12 -> "XII", ...). Only ever called with small, human-scale
/// choice counts, but the algorithm itself has no upper bound.
String _toRoman(int number) {
  var remaining = number;
  final buffer = StringBuffer();
  for (final (value, symbol) in _romanNumerals) {
    while (remaining >= value) {
      buffer.write(symbol);
      remaining -= value;
    }
  }
  return buffer.toString();
}

/// V2 reading-screen choice: same tactile press-and-brighten feel as
/// [ChoiceButton], with a Roman numeral standing in for the plain accent
/// rail — "las decisiones son un acto" (V2 design prototype §1a). Not yet
/// wired into [GameScreen]; introduced here in isolation per V2
/// Implementation Plan Stage 1.
class ChoiceCard extends StatefulWidget {
  const ChoiceCard({
    super.key,
    required this.index,
    required this.label,
    required this.onTap,
  });

  /// 1-based position among the choices offered this turn — spelled out as
  /// a Roman numeral (I, II, III, ...), matching the V2 prototype.
  final int index;

  final String label;
  final VoidCallback onTap;

  @override
  State<ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<ChoiceCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _pressed ? AetherColors.goldBright : AetherColors.gold;
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: AetherMotion.fast,
        curve: AetherMotion.standard,
        child: AnimatedContainer(
          duration: AetherMotion.fast,
          padding: const EdgeInsets.symmetric(
              horizontal: AetherSpace.lg, vertical: AetherSpace.lg),
          decoration: BoxDecoration(
            color: _pressed ? AetherColors.surfaceRaised : AetherColors.surface,
            borderRadius: AetherRadius.allMd,
            border: Border.all(
              color: _pressed
                  ? AetherColors.gold.withValues(alpha: 0.7)
                  : AetherColors.hairlineStrong,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  _toRoman(widget.index),
                  textAlign: TextAlign.center,
                  style: AetherType.title.copyWith(color: accent, fontSize: 15),
                ),
              ),
              const SizedBox(width: AetherSpace.md),
              Expanded(child: Text(widget.label, style: AetherType.label)),
              const SizedBox(width: AetherSpace.sm),
              Icon(Icons.chevron_right,
                  size: 20, color: accent.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
