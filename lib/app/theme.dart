import 'package:flutter/material.dart';

/// Minimal xianxia theming (CLAUDE.md §9 / GDD §9): ink-dark background, etheric
/// gold accents, a serif face for narration. Per-world theming comes later; for
/// Fase 0 this single mood is enough to make the world feel like a place.
class AetherTheme {
  static const Color ink = Color(0xFF14110F);
  static const Color inkSoft = Color(0xFF1F1B18);
  static const Color gold = Color(0xFFC9A24B);
  static const Color goldSoft = Color(0xFFE7D6A6);
  static const Color parchment = Color(0xFFEDE6D6);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: ink,
      colorScheme: base.colorScheme.copyWith(
        primary: gold,
        secondary: goldSoft,
        surface: inkSoft,
      ),
      textTheme: base.textTheme.copyWith(
        // Narration: serif, generous line height, easy to read.
        bodyLarge: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 19,
          height: 1.6,
          color: parchment,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w600,
          color: goldSoft,
          letterSpacing: 0.5,
        ),
        labelLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: parchment,
        ),
      ),
    );
  }
}
