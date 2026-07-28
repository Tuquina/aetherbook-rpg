import '../core/engine/action_resolution.dart';
import '../core/engine/free_action_classification.dart';
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
    this.nodeFixedReveals = const [],
    this.nodeForbiddenReveals = const [],
    this.nodeGoal,
    this.isFreeform = false,
    this.vowText,
    this.avoidedThemes = const [],
  });

  final World world;
  final Character character;
  final String playerAction;

  /// The already-resolved mechanics. `null` when there was nothing to roll:
  /// either an unconditional curated `StoryChoice`/`HubActivity` (a real
  /// action, carried in [playerAction], that never needed a check), or a
  /// freeform "continue" turn with no specific action at all (`playerAction`
  /// empty) — see `GameController.continueStory`. The opening/seed turn
  /// never reaches the narrator at all, so it isn't a third case.
  final ActionResolution? resolution;

  /// Short-term memory: the last few turns, literal (CLAUDE.md §6).
  final List<String> recentTurns;

  /// Medium-term memory: the ~150-word digest regenerated every few turns
  /// (CLAUDE.md §6, GDD §5.3). `null` until enough turns have accumulated.
  final String? memoryDigest;

  /// Facts the current `StoryNode` requires the narrator to include (Fase 7's
  /// `fixedReveals`/campaign-bible's "hechos, revelación"). Empty for a
  /// freeform world with no curated node.
  final List<String> nodeFixedReveals;

  /// Facts the current `StoryNode` forbids the narrator from revealing yet.
  final List<String> nodeForbiddenReveals;

  /// The current `BoundedCorridorNode`'s single objective, when inside one —
  /// keeps a generative corridor's free-text turns from drifting into new
  /// milestones (campaign-bible §9.1/§18.8). `null` outside a corridor.
  final String? nodeGoal;

  /// Whether this world has no `StoryGraph` at all (100% AI-generated, no
  /// curated content) — tells the narrator prompt to actively offer its own
  /// `suggested_choices` rather than relying on curated content to drive the
  /// story forward (CLAUDE.md Fase 2).
  final bool isFreeform;

  /// The chargen vow's text (V2 §6a Perfil), resolved from `World.vows` via
  /// `character.vowId` — `null` for a world with no vow step, or a character
  /// created before it existed.
  final String? vowText;

  /// Content the player asked the narrator to avoid (V2 §6b Ajustes),
  /// already resolved to human-readable labels — empty for the common case
  /// of a player who never touched this setting.
  final List<String> avoidedThemes;
}

/// The check a suggested choice would trigger if taken — shown to the UI so
/// the player can see what's at stake before choosing (campaign-bible
/// §18.5/§18.10). The narrator only *suggests* this; the actual attribute and
/// difficulty used at resolution time are still decided in code.
class ExpectedCheck {
  const ExpectedCheck({required this.attribute, this.difficultyId});

  final String attribute;

  /// A world/node-declared difficulty band id (e.g. `"standard"`), or `null`
  /// when the choice carries no meaningful difficulty of its own.
  final String? difficultyId;
}

/// A single suggested choice (campaign-bible §18.5): a stable [id] for
/// analytics/critical-choice tracking (§19.4), the visible [label], and
/// optionally the [intent]/[expectedCheck] the narrator believes this choice
/// would resolve as.
class SuggestedChoice {
  const SuggestedChoice({
    required this.id,
    required this.label,
    this.intent,
    this.expectedCheck,
  });

  final String id;
  final String label;
  final ActionIntent? intent;
  final ExpectedCheck? expectedCheck;
}

/// Whether the narrator considers the current node still in play, or ready
/// for the engine to advance the graph (campaign-bible §18.5/§18.8).
enum NodeStatus {
  active,
  readyToExit;

  static NodeStatus fromWire(String? raw) {
    return raw == 'ready_to_exit' ? NodeStatus.readyToExit : NodeStatus.active;
  }
}

/// The narrator's structured output (campaign-bible §18.5). The AI returns
/// only this shape. [stateDeltas] here are **proposals** the engine validates
/// before applying (§2.3) — see `ProposedStateDelta.toStateDelta`.
class NarratorResponse {
  const NarratorResponse({
    required this.narration,
    required this.suggestedChoices,
    required this.stateDeltas,
    required this.imagePrompt,
    required this.tone,
    this.memoryFacts = const [],
    this.nodeStatus = NodeStatus.active,
  });

  final String narration;
  final List<SuggestedChoice> suggestedChoices;
  final List<ProposedStateDelta> stateDeltas;
  final String imagePrompt;
  final String tone;

  /// Discrete facts to fold into medium/long-term memory (campaign-bible
  /// §18.5/§18.9), distinct from the free-prose diary digest.
  final List<String> memoryFacts;
  final NodeStatus nodeStatus;
}

/// The contract the game depends on. Concrete narrators — the fake now, a
/// Gemini-backed Edge Function later — implement this. The client never knows
/// which provider is behind it (CLAUDE.md §2.6, §4).
abstract class NarratorPort {
  Future<NarratorResponse> narrate(NarratorRequest request);
}
