import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Type system. Two voices:
///  - **Serif** (`_serif`) is the tome's voice: world titles and narration.
///    Warm, literary, generous line-height — this *is* the gameplay (GDD §9).
///  - **Sans** (system default) is the chrome's voice: labels, stats, buttons.
///
/// System fonts are used deliberately (offline, zero asset weight). A future
/// pass can bundle display faces (e.g. Cinzel / EB Garamond) by swapping the
/// family names here — nothing else changes.
abstract final class AetherType {
  static const String _serif = 'Georgia';

  /// Big ceremonial moments: world name, screen titles.
  static const TextStyle display = TextStyle(
    fontFamily: _serif,
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AetherColors.goldSoft,
  );

  /// Section titles inside the Codex and panels.
  static const TextStyle title = TextStyle(
    fontFamily: _serif,
    fontSize: 19,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AetherColors.goldSoft,
  );

  /// The narration — the sacred text. Serif, roomy, easy on the eyes.
  static const TextStyle narration = TextStyle(
    fontFamily: _serif,
    fontSize: 19,
    height: 1.68,
    color: AetherColors.parchment,
  );

  /// Body copy in the Codex and dialogs (still serif, slightly tighter).
  static const TextStyle body = TextStyle(
    fontFamily: _serif,
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
