import '../core/engine/action_resolution.dart';
import '../core/engine/state_delta.dart';
import '../core/state/character.dart';
import '../core/world/world.dart';

/// Everything the narrator needs to narrate a single turn (CLAUDE.md §5.1).
/// The mechanics are already resolved: the narrator turns a resolved outcome
/// into prose and never sees a real RNG or decides mechanics.
class NarratorRequest {
  const NarratorRequest({
    required this.world,
    required this.character,
    required this.playerAction,
    required this.resolution,
    this.recentTurns = const [],
    this.memoryDigest,
  });

  final World world;
  final Character character;
  final String playerAction;

  /// The already-resolved mechanics. `null` only for the opening/seed turn,
  /// where the player has not acted yet.
  final ActionResolution? resolution;

  /// Short-term memory: the last few turns, literal (CLAUDE.md §6).
  final List<String> recentTurns;

  /// Medium-term memory: the ~150-word digest regenerated every few turns
  /// (CLAUDE.md §6, GDD §5.3). `null` until enough turns have accumulated.
  final String? memoryDigest;
}

/// The narrator's structured output (CLAUDE.md §5). The AI returns only this
/// shape. [stateDeltas] here are **proposals** the engine validates before
/// applying (§2.3).
class NarratorResponse {
  const NarratorResponse({
    required this.narration,
    required this.suggestedChoices,
    required this.stateDeltas,
    required this.imagePrompt,
    required this.tone,
  });

  final String narration;
  final List<String> suggestedChoices;
  final List<StateDelta> stateDeltas;
  final String imagePrompt;
  final String tone;
}

/// The contract the game depends on. Concrete narrators — the fake now, a
/// Gemini-backed Edge Function later — implement this. The client never knows
/// which provider is behind it (CLAUDE.md §2.6, §4).
abstract class NarratorPort {
  Future<NarratorResponse> narrate(NarratorRequest request);
}
