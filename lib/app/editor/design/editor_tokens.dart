import 'package:flutter/material.dart';

import '../../../core/narrative/story_node.dart';
import '../../design/tokens.dart';

/// Campaign editor design tokens (V2 design prototype §9a-9j). Scoped to
/// `lib/app/editor/` only — everywhere else in the app keeps reading
/// `AetherColors`/`AetherType` exactly as before. Two things the shared
/// tokens don't have, both needed pervasively across every editor screen:
///
///  - [EditorType]: the mockup's UI chrome voice is "Archivo" (labels,
///    badges, buttons), not the shared system-sans `AetherType.label`/
///    `.overline`/`.caption` — see `pubspec.yaml`'s font entry.
///  - [EditorNodeColors]: each `StoryNode` type gets its own signature
///    accent in the mockup (distinct from `AetherColors`' module accents,
///    which are a different, unrelated set of hues) — the node-graph map's
///    whole legibility rests on this color coding.
abstract final class EditorType {
  static const String _family = 'Archivo';

  /// Section eyebrows: "AÑADIR", "CAPÍTULOS", "QUÉ TIENE QUE CONSEGUIR...".
  static const TextStyle overline = TextStyle(
    fontFamily: _family,
    fontSize: 8.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AetherColors.parchmentFaint,
  );

  /// A node card's kind label ("ESCENA ESCRITA", "TRAMO LIBRE"...).
  static const TextStyle kicker = TextStyle(
    fontFamily: _family,
    fontSize: 8.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
  );

  /// Form field labels, sidebar item titles, button text.
  static const TextStyle label = TextStyle(
    fontFamily: _family,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: AetherColors.goldSoft,
  );

  /// Secondary line under a [label] (e.g. "Tú pones el texto").
  static const TextStyle hint = TextStyle(
    fontFamily: _family,
    fontSize: 9.5,
    fontWeight: FontWeight.w400,
    color: AetherColors.parchmentFaint,
  );

  /// Badges/pills ("2 opciones", "sin tirada", "una sola vez"...).
  static const TextStyle pill = TextStyle(
    fontFamily: _family,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AetherColors.parchmentDim,
  );

  /// Buttons and header actions.
  static const TextStyle button = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Metadata line, e.g. "Guardado hace 1 min".
  static const TextStyle meta = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AetherColors.parchmentFaint,
  );
}

/// Per-[StoryNode]-type accent colors (V2 design prototype §9a). Bright/dim
/// pairs follow the same "solid for the icon/label, low-alpha for the
/// border/background wash" pattern every card in the mockup uses.
abstract final class EditorNodeColors {
  /// `FixedAnchorNode` ("Escena escrita") — reuses the app's own gold, since
  /// the mockup's fixed-anchor color *is* `AetherColors.goldBright`.
  static const Color fixedAnchor = AetherColors.goldBright;

  /// `BoundedCorridorNode` ("Tramo libre") — mint.
  static const Color boundedCorridor = Color(0xFF7FD4C1);

  /// `StateHubNode` ("Alto en el camino") — cyan.
  static const Color stateHub = Color(0xFF55E0F0);

  /// `ResolutionNode` ("Final") — violet.
  static const Color resolution = Color(0xFFB98DEB);

  /// A choice/exit/fallback that targets a node id absent from the graph
  /// (`StoryGraph.unknownTargetIds`) — "Cabo suelto".
  static const Color danger = AetherColors.failure;

  /// A checked choice/activity ("Esto puede salir mal") — mustard, distinct
  /// from [fixedAnchor]'s brighter gold so a risky option reads apart from
  /// an ordinary one even within the same gold-toned card.
  static const Color risk = Color(0xFFD8B65E);

  static Color forNode(StoryNode node) => switch (node) {
        FixedAnchorNode() => fixedAnchor,
        BoundedCorridorNode() => boundedCorridor,
        StateHubNode() => stateHub,
        ResolutionNode() => resolution,
      };

  static String kindLabel(StoryNode node) => switch (node) {
        FixedAnchorNode() => 'Escena escrita',
        BoundedCorridorNode() => 'Tramo libre',
        StateHubNode() => 'Alto en el camino',
        ResolutionNode() => 'Final',
      };

  static IconData kindIcon(StoryNode node) => switch (node) {
        FixedAnchorNode() => Icons.edit_note_rounded,
        BoundedCorridorNode() => Icons.route_rounded,
        StateHubNode() => Icons.hub_rounded,
        ResolutionNode() => Icons.flag_rounded,
      };
}
