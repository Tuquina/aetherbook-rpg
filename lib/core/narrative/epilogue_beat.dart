import '../state/character.dart';
import 'gate.dart';

/// One conditional beat of an epilogue's assembly (campaign-bible §16.8):
/// the epilogue isn't a menu of endings, it's composed of five fixed
/// "movements" (la mañana siguiente / una persona afectada / la nueva regla
/// / el protagonista / la tablilla), each with several gate-conditioned
/// variants. [movement] groups beats that compete for the same slot; the
/// caller (Fase 8) picks the first beat per movement whose [gate] the final
/// character state satisfies.
class EpilogueBeat {
  const EpilogueBeat({
    required this.movement,
    required this.text,
    this.gate = const AlwaysGate(),
  });

  final String movement;
  final String text;
  final Gate gate;

  bool isSatisfiedBy(Character character) => gate.isSatisfiedBy(character);

  factory EpilogueBeat.fromJson(Map<String, dynamic> json) {
    return EpilogueBeat(
      movement: json['movement'] as String,
      text: json['text'] as String,
      gate: Gate.fromJson((json['gate'] as Map?)?.cast<String, dynamic>()),
    );
  }
}
