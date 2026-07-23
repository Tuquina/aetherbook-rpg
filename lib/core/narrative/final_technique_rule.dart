import '../state/character.dart';
import 'gate.dart';

/// One priority rule for granting the final technique on entering the ritual
/// (campaign-bible §7.5): rules are evaluated in order, the first whose
/// [gate] is satisfied wins — the last rule is expected to use an
/// `AlwaysGate` (the campaign's `yo_me_nombro` catch-all) so a technique is
/// always granted.
class FinalTechniqueRule {
  const FinalTechniqueRule({required this.gate, required this.techniqueId});

  final Gate gate;
  final String techniqueId;

  bool isSatisfiedBy(Character character) => gate.isSatisfiedBy(character);

  factory FinalTechniqueRule.fromJson(Map<String, dynamic> json) {
    return FinalTechniqueRule(
      gate: Gate.fromJson((json['gate'] as Map?)?.cast<String, dynamic>()),
      techniqueId: json['technique_id'] as String,
    );
  }
}
