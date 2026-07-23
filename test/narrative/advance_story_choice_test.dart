import 'package:aetherbook/core/narrative/advance_story_choice.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

const _character = Character(
  name: 'Discípulo',
  level: 1,
  exp: 0,
  attributes: {},
  resources: {'qi': 10},
);

final _graph = StoryGraph.fromJson({
  'start_node': 'beat_1',
  'nodes': {
    'beat_1': {'narration': 'Inicio'},
    'beat_2': {'narration': 'Templo'},
  },
});

void main() {
  const advance = AdvanceStoryChoice();

  test('moves to the choice\'s target node', () {
    const choice = StoryChoice(label: 'Ir al templo', targetNodeId: 'beat_2');
    final result = advance(graph: _graph, character: _character, choice: choice);
    expect(result.nextNode.id, 'beat_2');
  });

  test('applies the choice\'s effects to the character', () {
    const choice = StoryChoice(
      label: 'Ir al templo',
      targetNodeId: 'beat_2',
      effects: [
        StateDelta(type: StateDeltaType.exp, key: 'exp', value: 100),
        StateDelta(type: StateDeltaType.flag, key: 'llego_al_templo', value: true),
      ],
    );
    final result = advance(graph: _graph, character: _character, choice: choice);
    expect(result.character.exp, 100);
    expect(result.character.flag('llego_al_templo'), isTrue);
  });

  test('rejects invalid effects the same way ApplyStateDeltas would', () {
    const choice = StoryChoice(
      label: 'Ir al templo',
      targetNodeId: 'beat_2',
      effects: [
        StateDelta(type: StateDeltaType.exp, key: 'exp', value: -50),
      ],
    );
    final result = advance(graph: _graph, character: _character, choice: choice);
    expect(result.character.exp, 0);
  });

  test('throws when the target node does not exist in the graph', () {
    const choice = StoryChoice(label: 'x', targetNodeId: 'no_existe');
    expect(
      () => advance(graph: _graph, character: _character, choice: choice),
      throwsArgumentError,
    );
  });
}
