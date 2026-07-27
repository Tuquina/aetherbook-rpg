import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Type system. Two serif voices plus one sans:
///  - **Marcellus** (`_display`) is the ceremonial voice: world/screen titles,
///    the wordmark. Used at its one shipped weight (400) — Flutter synthesizes
///    the bold/emphasis some call sites request, since Marcellus has no bold
///    cut to bundle.
///  - **Spectral** (`_narration`) is the tome's reading voice: narration and
///    body copy. Warm, literary, generous line-height — this *is* the
///    gameplay (GDD §9).
///  - **Sans** (system default) is the chrome's voice: labels, stats, buttons.
///
/// V2 Implementation Plan, Stage 1: both serif faces are vendored under
/// `assets/fonts/` (see `pubspec.yaml`), replacing the system Georgia
/// placeholder this file used through Fase 1. `AetherType` is a single shared
/// token file by design ("nothing hardcoded in widgets" — see the module
/// doc above) — every screen that reads `display`/`title`/`narration`/`body`
/// picks up the new faces at once; there is no per-screen font override.
abstract final class AetherType {
  static const String _display = 'Marcellus';
  static const String _narration = 'Spectral';

  /// Big ceremonial moments: world name, screen titles.
  static const TextStyle display = TextStyle(
    fontFamily: _display,
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AetherColors.goldSoft,
  );

  /// Section titles inside the Codex and panels.
  static const TextStyle title = TextStyle(
    fontFamily: _display,
    fontSize: 19,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AetherColors.goldSoft,
  );

  /// The narration — the sacred text. Serif, roomy, easy on the eyes.
  static const TextStyle narration = TextStyle(
    fontFamily: _narration,
    fontSize: 19,
    height: 1.68,
    color: AetherColors.parchment,
  );

  /// Body copy in the Codex and dialogs (still serif, slightly tighter).
  static const TextStyle body = TextStyle(
    fontFamily: _narration,
    fontSize: 16,
    height: 1.55,
    color: AetherColors.parchment,
  );

  /// Interactive labels: choice buttons.
  static const TextStyle label = TextStyle(
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AetherColors.parchment,
  );

  /// Small caps-ish overlines for section eyebrows / stat labels.
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AetherColors.parchmentFaint,
  );

  /// Captions and metadata.
  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    height: 1.3,
    color: AetherColors.parchmentDim,
  );

  /// Numeric display for dice/stat figures — tabular, confident.
  static const TextStyle numeral = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AetherColors.parchment,
  );
}
