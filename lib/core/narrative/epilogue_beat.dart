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

/// Assembles [beats] into ordered prose for [character]: groups by
/// [EpilogueBeat.movement] (preserving each movement's first appearance
/// order), and within a movement picks the *first* beat whose gate is
/// satisfied — the same "first satisfied variant per slot" rule the
/// campaign-bible epilogue/ending sections describe. A movement with no
/// satisfied beat contributes nothing (content authors are expected to
/// always include an `AlwaysGate` catch-all per movement — content tests
/// enforce that, this function stays permissive).
List<String> assembleEpilogueBeats(
  List<EpilogueBeat> beats,
  Character character,
) {
  final movementOrder = <String>[];
  final byMovement = <String, List<EpilogueBeat>>{};
  for (final beat in beats) {
    if (!byMovement.containsKey(beat.movement)) {
      movementOrder.add(beat.movement);
    }
    (byMovement[beat.movement] ??= []).add(beat);
  }

  final result = <String>[];
  for (final movement in movementOrder) {
    for (final beat in byMovement[movement]!) {
      if (beat.isSatisfiedBy(character)) {
        result.add(beat.text);
        break;
      }
    }
  }
  return result;
}
