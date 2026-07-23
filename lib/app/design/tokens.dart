import 'package:flutter/widgets.dart';

/// Aetherbook design system — foundation tokens.
///
/// The visual language ("Aether Codex"): an enchanted tome from which worlds
/// spill. Deep ink backgrounds, etheric gold light, warm parchment text for
/// the narration (the "sacred text"), refined minimal chrome. Every color,
/// space and motion value in the app flows from here — nothing is hardcoded in
/// widgets, so a future per-world reskin (GDD §9) only touches these tokens.

/// Color palette. Semantic names first; raw swatches are private.
abstract final class AetherColors {
  // ── Surfaces (ink / void) ──────────────────────────────────────────────
  /// The deepest background, behind everything.
  static const Color void_ = Color(0xFF0E0C0B);

  /// Primary app background.
  static const Color ink = Color(0xFF15120F);

  /// Raised surfaces: cards, the choices bar, the status bar.
  static const Color surface = Color(0xFF1D1813);

  /// A surface one step up: pressed / hovered / nested panels.
  static const Color surfaceRaised = Color(0xFF261F18);

  // ── Accent (aether gold) ───────────────────────────────────────────────
  /// The signature accent. Used sparingly for emphasis and interaction.
  static const Color gold = Color(0xFFC9A24B);

  /// Brighter gold for highlights, focus, critical moments.
  static const Color goldBright = Color(0xFFEAC978);

  /// Soft gold for accented text that must stay legible.
  static const Color goldSoft = Color(0xFFE7D6A6);

  /// Very low-alpha gold for glows and washes.
  static const Color goldGlow = Color(0x33C9A24B);

  // ── Text (parchment) ───────────────────────────────────────────────────
  /// Primary reading text (narration).
  static const Color parchment = Color(0xFFECE4D3);

  /// Secondary text: labels, metadata.
  static const Color parchmentDim = Color(0xFFB4AA97);

  /// Tertiary text: hints, captions, disabled.
  static const Color parchmentFaint = Color(0xFF7E7565);

  // ── Hairlines & dividers ───────────────────────────────────────────────
  static const Color hairline = Color(0x22C9A24B);
  static const Color hairlineStrong = Color(0x44C9A24B);

  // ── Outcome bands (the "fate" system, GDD §4.4) ────────────────────────
  /// Failure — a muted crimson, never alarming red.
  static const Color failure = Color(0xFFC96F63);
  static const Color failureDim = Color(0x22C96F63);

  /// Success — jade.
  static const Color success = Color(0xFF74B98A);
  static const Color successDim = Color(0x2274B98A);

  /// Critical success — the accent gold itself, the highest band.
  static const Color critical = goldBright;
  static const Color criticalDim = Color(0x33EAC978);
}

/// Spacing scale (4-based). Use these, never raw numbers, for padding & gaps.
abstract final class AetherSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Corner radii.
abstract final class AetherRadius {
  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(18);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius allSm = BorderRadius.all(sm);
  static const BorderRadius allMd = BorderRadius.all(md);
  static const BorderRadius allLg = BorderRadius.all(lg);
  static const BorderRadius allPill = BorderRadius.all(pill);
}

/// Motion durations & curves. Consistent timing makes the app feel coherent.
abstract final class AetherMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);

  /// Full length of the fate-roll reveal animation.
  static const Duration roll = Duration(milliseconds: 1500);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}

/// Reusable elevation glows (soft, warm — never hard drop shadows).
abstract final class AetherShadow {
  static const List<BoxShadow> panel = [
    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static List<BoxShadow> glow(Color color, {double strength = 0.5}) => [
        BoxShadow(
          color: color.withValues(alpha: strength),
          blurRadius: 28,
          spreadRadius: -4,
        ),
      ];
}
