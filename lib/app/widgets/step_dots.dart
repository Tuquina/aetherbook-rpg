import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// A row of pip indicators for a multi-step flow — first built for
/// `ChargenScreen`'s 3-step wizard, extracted here so the onboarding flow
/// (V2 design prototype §6c-e) can reuse the same building block instead of
/// a second hand-rolled copy.
///
/// Two looks, matching how each flow actually reads progress:
/// - `highlightCurrentOnly: false` (`ChargenScreen`'s original) — every pip
///   up to and including [current] fills gold, like a trail of steps
///   completed so far. All pips the same width.
/// - `highlightCurrentOnly: true` (onboarding) — only [current] is gold and
///   wider; every other pip (before or after) stays uniformly dim. Reads as
///   "which page am I on", not "how much progress so far".
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.count,
    required this.current,
    this.highlightCurrentOnly = false,
  });

  final int count;

  /// 0-based index of the step currently shown.
  final int current;

  final bool highlightCurrentOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.only(left: 5),
            width: highlightCurrentOnly ? (i == current ? 22 : 9) : 18,
            height: 3,
            decoration: BoxDecoration(
              color: (highlightCurrentOnly ? i == current : i <= current)
                  ? AetherColors.gold
                  : AetherColors.hairlineStrong,
              borderRadius: AetherRadius.allPill,
            ),
          ),
      ],
    );
  }
}
