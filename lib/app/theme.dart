import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'design/typography.dart';

export 'design/tokens.dart';
export 'design/typography.dart';

/// Builds the app's [ThemeData] from the design tokens ([AetherColors],
/// [AetherType]). Widgets read colors/text from the tokens directly; this
/// theme wires up the Material defaults (buttons, inputs, text selection) so
/// stock widgets also inherit the Aether look.
abstract final class AetherTheme {
  // Convenience aliases so existing call sites (AetherTheme.gold, …) keep
  // working while pointing at the token palette.
  static const Color ink = AetherColors.ink;
  static const Color inkSoft = AetherColors.surface;
  static const Color gold = AetherColors.gold;
  static const Color goldSoft = AetherColors.goldSoft;
  static const Color parchment = AetherColors.parchment;

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AetherColors.ink,
      colorScheme: base.colorScheme.copyWith(
        primary: AetherColors.gold,
        secondary: AetherColors.goldBright,
        surface: AetherColors.surface,
        onSurface: AetherColors.parchment,
        error: AetherColors.failure,
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: AetherType.display,
        titleLarge: AetherType.title,
        bodyLarge: AetherType.narration,
        bodyMedium: AetherType.body,
        labelLarge: AetherType.label,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AetherColors.gold,
        selectionColor: AetherColors.goldGlow,
        selectionHandleColor: AetherColors.gold,
      ),
      splashColor: AetherColors.goldGlow,
      highlightColor: AetherColors.goldGlow,
      dividerColor: AetherColors.hairline,
    );
  }
}
