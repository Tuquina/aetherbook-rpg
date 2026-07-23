import '../engine/action_resolution.dart';
import 'gate.dart';
import 'story_choice.dart';

/// The shape [StoryChoice] and `HubActivity` both already have — a check
/// (attribute/difficulty) and outcome-branch resolution. They stay separate,
/// duplicated classes (Fase 7's deliberate call: only two call sites, not
/// worth a shared base), but sharing this interface lets `ResolveStoryChoice`
/// (Fase 8) resolve either one polymorphically.
abstract interface class Checkable {
  bool get requiresCheck;
  String? get checkAttribute;
  int? get checkDifficulty;

  /// When satisfied by the resolving character, this check rolls with
  /// advantage (campaign-bible §6.5/§25.4 "advantage_when") — e.g. a
  /// companion's specialty applying. `null` means this check never grants
  /// advantage on its own.
  Gate? get advantageWhen;

  /// When satisfied, this check rolls with disadvantage — e.g. an
  /// explicitly harder attempt authored as "[Tirada con desventaja]". `null`
  /// means never. If both this and [advantageWhen] are satisfied at once,
  /// `combineRollModifiers` cancels them back to a normal roll.
  Gate? get disadvantageWhen;

  ChoiceOutcome outcomeFor(ActionOutcome outcome);
}
