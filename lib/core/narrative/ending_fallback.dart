import '../state/character.dart';
import 'gate.dart';

/// A redirect for when an [Ending]'s resolution check fails and the story
/// still needs to land on a *different* mechanical ending (campaign-bible
/// §16.1: Nuevo Pacto's failure can resolve as `portador_del_margen` or
/// `nuevo_pacto_fracturado`, depending on the character's state). Every other
/// ending's failure just applies a worse cost under the *same* `ending_id` —
/// only Nuevo Pacto needs this. Rules are evaluated in order, first
/// satisfied [gate] wins; the last rule is expected to use an `AlwaysGate`.
class EndingFallback {
  const EndingFallback({required this.gate, required this.endingId});

  final Gate gate;
  final String endingId;

  bool isSatisfiedBy(Character character) => gate.isSatisfiedBy(character);

  factory EndingFallback.fromJson(Map<String, dynamic> json) {
    return EndingFallback(
      gate: Gate.fromJson((json['gate'] as Map?)?.cast<String, dynamic>()),
      endingId: json['ending_id'] as String,
    );
  }
}
