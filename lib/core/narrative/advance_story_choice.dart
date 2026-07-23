import '../engine/apply_state_deltas.dart';
import '../state/character.dart';
import 'story_choice.dart';
import 'story_graph.dart';
import 'story_node.dart';

/// Result of taking a [StoryChoice]: the character with its effects applied
/// and the node the graph moved to.
class StoryAdvance {
  const StoryAdvance({required this.character, required this.nextNode});

  final Character character;
  final StoryNode nextNode;
}

/// Moves the story graph forward along a chosen edge. A choice's [effects]
/// are curated by the content author, but they still go through
/// [ApplyStateDeltas] — the same validation AI-proposed deltas get
/// (CLAUDE.md §2.3). The state manda regardless of who authored the change.
class AdvanceStoryChoice {
  const AdvanceStoryChoice({ApplyStateDeltas? applyDeltas})
      : _applyDeltas = applyDeltas ?? const ApplyStateDeltas();

  final ApplyStateDeltas _applyDeltas;

  StoryAdvance call({
    required StoryGraph graph,
    required Character character,
    required StoryChoice choice,
  }) {
    final application = _applyDeltas(character, choice.effects);
    return StoryAdvance(
      character: application.character,
      nextNode: graph.nodeById(choice.targetNodeId),
    );
  }
}
