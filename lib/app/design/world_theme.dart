import 'package:flutter/widgets.dart';

import '../../core/world/world.dart';
import 'tokens.dart';

/// Resolves a [World]'s per-world visual theme (V2 design prototype
/// §4a-4d: "Theming por mundo") into real [Color]s. Lives in `lib/app/`, not
/// `core/`, because [World] itself only carries raw hex strings — `core/`
/// stays Flutter-free (see `World.themeAccentHex` doc comment).
///
/// A world that hasn't declared any theme fields yet resolves to exactly
/// the app's existing global palette (`AetherColors.gold`/`ink`/`nova`), so
/// adding this never changes anything for content that predates it.
class WorldTheme {
  const WorldTheme({
    required this.accent,
    required this.base,
    required this.secondary,
  });

  final Color accent;
  final Color base;
  final Color secondary;

  factory WorldTheme.forWorld(World world) => WorldTheme(
        accent: parseHexColor(world.themeAccentHex) ?? AetherColors.gold,
        base: parseHexColor(world.themeBaseHex) ?? AetherColors.ink,
        secondary: parseHexColor(world.themeSecondaryHex) ?? AetherColors.nova,
      );

  /// Parses a `"#RRGGBB"` or `"RRGGBB"` string into an opaque [Color].
  /// Returns `null` for anything else (missing, malformed, wrong length) —
  /// callers fall back to a default rather than crashing on bad content.
  static Color? parseHexColor(String? hex) {
    if (hex == null) return null;
    var value = hex.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length != 6) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }
}
