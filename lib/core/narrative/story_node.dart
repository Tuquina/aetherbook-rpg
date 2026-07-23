import '../state/character.dart';
import 'story_choice.dart';

/// `fixed` nodes carry authored, guaranteed-quality prose. `generative` nodes
/// carry a guardrail instruction and let the AI improvise within it — the
/// "railroading suave" of hybrid mode (GDD §4.5).
enum NodeKind { fixed, generative }

/// A single beat in the story graph (GDD §4.1). Modeled as part of a
/// directed graph, not a tree — choices from different nodes can reconverge
/// on the same target.
class StoryNode {
  const StoryNode({
    required this.id,
    required this.kind,
    this.narration = '',
    this.generationInstruction = '',
    this.allowsFreeform = false,
    this.choices = const [],
  });

  final String id;
  final NodeKind kind;

  /// Fixed prose shown as-is, used when [kind] is [NodeKind.fixed].
  final String narration;

  /// Guardrail text for the AI narrator, used when [kind] is
  /// [NodeKind.generative] — e.g. "estás en el beat 3, el objetivo es que el
  /// jugador llegue al templo; puede desviarse pero reconducí" (GDD §4.5).
  final String generationInstruction;

  /// Whether the player can also type a free action on this node, in
  /// addition to picking one of [choices].
  final bool allowsFreeform;

  final List<StoryChoice> choices;

  /// The choices whose gate is currently satisfied, in authored order (GDD
  /// §4.1: gates decide which options *appear*, not just which succeed).
  List<StoryChoice> availableChoices(Character character) => [
        for (final choice in choices)
          if (choice.isAvailableTo(character)) choice,
      ];

  factory StoryNode.fromJson(String id, Map<String, dynamic> json) {
    return StoryNode(
      id: id,
      kind: (json['kind'] as String?) == 'generative'
          ? NodeKind.generative
          : NodeKind.fixed,
      narration: json['narration'] as String? ?? '',
      generationInstruction: json['generation_instruction'] as String? ?? '',
      allowsFreeform: json['allows_freeform'] as bool? ?? false,
      choices: [
        for (final c in (json['choices'] as List? ?? const []))
          StoryChoice.fromJson((c as Map).cast<String, dynamic>()),
      ],
    );
  }
}
