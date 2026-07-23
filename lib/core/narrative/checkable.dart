import '../engine/action_resolution.dart';
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
  ChoiceOutcome outcomeFor(ActionOutcome outcome);
}
