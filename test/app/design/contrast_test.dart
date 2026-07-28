// Contrast verification for the per-world palettes (V2 Stage 8) — real WCAG
// 2.1 numbers, not visual approval. The plan's own goal specifically named
// "Cyberpunk's cyan-on-near-black" as needing a real check; computed here,
// it turns out to be one of the *highest*-contrast pairs of all five, not a
// risk — the assumption was wrong, and this test is what proves that rather
// than leaving it as an unverified guess.
//
// Two different WCAG thresholds apply depending on what's actually rendered
// in each color, confirmed by reading the call sites rather than assumed:
// - `theme.accent`/`theme.secondary` are only ever used for icons, borders,
//   and (via `WorldTheme.titleStyle`) large display titles in this app —
//   never small body text (`character_sheet_sheet.dart`'s `_InfoChip`, for
//   instance, always renders its label in `AetherColors.parchment`, tinting
//   only the icon/border with the theme color). WCAG 2.1 SC 1.4.11
//   ("Non-text Contrast") sets a 3:1 minimum for these.
// - `AetherColors.parchment`/`parchmentDim` are the actual narration-reading
//   text color, rendered directly over a world's own themed backdrop on
//   mobile (`_ReadingFrame` only wraps the reading column in an opaque
//   `AetherColors.ink` panel at wide/split-view widths — below that, the
//   themed `AetherBackground` shows straight through). WCAG's regular AA
//   text minimum, 4.5:1, applies here.
import 'dart:math' as math;

import 'package:aetherbook/app/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 relative luminance (§1.4.3's formula) — `Color.r/g/b` are
/// already 0.0-1.0 floats in this Flutter version, no /255 needed.
double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio (§1.4.3), from 1:1 (identical) to 21:1 (black on
/// white) — symmetric, so argument order doesn't matter.
double _contrast(Color a, Color b) {
  final l1 = _relativeLuminance(a), l2 = _relativeLuminance(b);
  final lighter = math.max(l1, l2), darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// A world's 3 core theme colors (`World.themeAccentHex`/`themeBaseHex`/
/// `themeSecondaryHex`), copied verbatim from `assets/worlds/*.json` rather
/// than parsed from the file — a deliberate value-based check (this file
/// asserts the *design decision* is sound), not a duplicate of
/// `world_theme_test.dart`'s parsing coverage.
class _Palette {
  const _Palette(this.name, this.accent, this.base, this.secondary);
  final String name;
  final Color accent;
  final Color base;
  final Color secondary;
}

const _palettes = [
  _Palette('Isekai', Color(0xFFEAC978), Color(0xFF15120F), Color(0xFF9B5DE0)),
  _Palette('Xianxia', Color(0xFF7FD4C1), Color(0xFF0F1D1A), Color(0xFFD8B65E)),
  _Palette('Superhéroes', Color(0xFFF0564A), Color(0xFF170F0E), Color(0xFF4C8BF0)),
  _Palette('Cyberpunk', Color(0xFF55E0F0), Color(0xFF0C1016), Color(0xFFFF4FA3)),
  _Palette('Post-apocalíptico', Color(0xFFB8B27A), Color(0xFF161611), Color(0xFFD2762F)),
];

void main() {
  group('baseline palette (regression guard — no world theme applied)', () {
    test('narration text (parchment) on the original ink/void_ surfaces clears AAA (7:1)', () {
      expect(_contrast(AetherColors.parchment, AetherColors.void_), greaterThanOrEqualTo(7));
      expect(_contrast(AetherColors.parchment, AetherColors.ink), greaterThanOrEqualTo(7));
    });
  });

  group('per-world narration text contrast (parchment/parchmentDim on `base`, AA 4.5:1)', () {
    for (final p in _palettes) {
      test('${p.name}: parchment and parchmentDim on its own base both clear AA', () {
        expect(_contrast(AetherColors.parchment, p.base), greaterThanOrEqualTo(4.5),
            reason: '${p.name}: parchment narration text unreadable on its own backdrop');
        expect(_contrast(AetherColors.parchmentDim, p.base), greaterThanOrEqualTo(4.5),
            reason: '${p.name}: parchmentDim (secondary text) unreadable on its own backdrop');
      });
    }
  });

  group('per-world accent/secondary contrast (icons/borders/titles only — never small body '
      'text in this app, WCAG non-text minimum 3:1)', () {
    for (final p in _palettes) {
      test('${p.name}: accent and secondary both clear the non-text 3:1 minimum '
          'against base and against surfaceRaised', () {
        expect(_contrast(p.accent, p.base), greaterThanOrEqualTo(3),
            reason: '${p.name}: accent (icons/borders/titles) too low-contrast on its own base');
        expect(_contrast(p.accent, AetherColors.surfaceRaised), greaterThanOrEqualTo(3),
            reason: '${p.name}: accent too low-contrast on the app\'s raised-surface chips/cards');
        expect(_contrast(p.secondary, p.base), greaterThanOrEqualTo(3),
            reason: '${p.name}: secondary (alert/flag-tag role) too low-contrast on its own base');
        expect(_contrast(p.secondary, AetherColors.surfaceRaised), greaterThanOrEqualTo(3),
            reason: '${p.name}: secondary too low-contrast on the app\'s raised-surface chips/cards');
      });
    }
  });

  test(
      "Cyberpunk's cyan accent on its own near-black base -- the pair the plan's own goal "
      'named as needing a real check -- actually clears AAA (7:1), disproving the assumed risk',
      () {
    final cyberpunk = _palettes.firstWhere((p) => p.name == 'Cyberpunk');
    final ratio = _contrast(cyberpunk.accent, cyberpunk.base);
    expect(ratio, greaterThanOrEqualTo(7));
  });

  test("Postapoc's/the shared-family curated zombie campaign's custom title color "
      '(#D6D2AC, `theme_title_color`) clears AA (4.5:1) against its own base', () {
    const titleColor = Color(0xFFD6D2AC);
    final postapoc = _palettes.firstWhere((p) => p.name == 'Post-apocalíptico');
    expect(_contrast(titleColor, postapoc.base), greaterThanOrEqualTo(4.5));
  });
}
