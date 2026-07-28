import 'package:flutter/widgets.dart';

import '../../core/world/world.dart';
import 'tokens.dart';

/// Which background texture (V2 §4a) an "in-world" screen (the scene, the
/// character sheet) should render behind its content — `radialWarm` is the
/// app's original, still-default treatment; the other four are Decision E's
/// follow-up. Deliberately not used by `MyStoriesScreen`/`WorldSelectScreen`
/// — the mockup itself keeps the library neutral (§4d).
enum WorldTextureKind { radialWarm, fog, hardDiagonal, scanline, grain }

WorldTextureKind? _textureFromString(String? value) => switch (value) {
      'radial_warm' => WorldTextureKind.radialWarm,
      'fog' => WorldTextureKind.fog,
      'hard_diagonal' => WorldTextureKind.hardDiagonal,
      'scanline' => WorldTextureKind.scanline,
      'grain' => WorldTextureKind.grain,
      _ => null,
    };

/// Resolves a [World]'s per-world visual theme (V2 design prototype
/// §4a-4d: "Theming por mundo") into real [Color]s/[TextStyle]s. Lives in
/// `lib/app/`, not `core/`, because [World] itself only carries raw hex
/// strings — `core/` stays Flutter-free (see `World.themeAccentHex` doc
/// comment).
///
/// A world that hasn't declared any theme fields yet resolves to exactly
/// the app's existing global palette (`AetherColors.gold`/`ink`/`nova`) and
/// typography (`AetherType.title`/`.display`'s own Marcellus/600), so adding
/// this never changes anything for content that predates it.
class WorldTheme {
  const WorldTheme({
    required this.accent,
    required this.base,
    required this.secondary,
    this.titleFontFamily,
    this.titleFontWeight,
    this.titleLetterSpacing,
    this.titleUppercase = false,
    this.titleColor,
    this.texture,
  });

  final Color accent;
  final Color base;
  final Color secondary;

  final String? titleFontFamily;
  final FontWeight? titleFontWeight;
  final double? titleLetterSpacing;
  final bool titleUppercase;
  final Color? titleColor;
  final WorldTextureKind? texture;

  factory WorldTheme.forWorld(World world) => WorldTheme(
        accent: parseHexColor(world.themeAccentHex) ?? AetherColors.gold,
        base: parseHexColor(world.themeBaseHex) ?? AetherColors.ink,
        secondary: parseHexColor(world.themeSecondaryHex) ?? AetherColors.nova,
        titleFontFamily: world.themeTitleFontFamily,
        titleFontWeight: world.themeTitleFontWeight == null
            ? null
            : FontWeight.values.firstWhere(
                (w) => w.value == world.themeTitleFontWeight,
                orElse: () => FontWeight.w400,
              ),
        titleLetterSpacing: world.themeTitleLetterSpacing,
        titleUppercase: world.themeTitleUppercase,
        titleColor: parseHexColor(world.themeTitleColorHex),
        texture: _textureFromString(world.themeTexture),
      );

  /// Applies this world's title-treatment tokens onto [base] (typically
  /// `AetherType.title`/`.display`) — only the fields the world actually
  /// declared override anything, so a themeless world's title renders
  /// byte-identical to today. [titleUppercase] isn't a `TextStyle` field
  /// (Flutter has no text-transform); apply `.toUpperCase()` to the string
  /// itself at the call site when this is `true`.
  TextStyle titleStyle(TextStyle base) => base.copyWith(
        fontFamily: titleFontFamily,
        fontWeight: titleFontWeight,
        letterSpacing: titleLetterSpacing,
        color: titleColor ?? base.color,
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
