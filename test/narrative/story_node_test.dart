import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

const _character = Character(
  name: 'Discípulo',
  level: 1,
  exp: 0,
  attributes: {},
  resources: {},
);

void main() {
  group('StoryNode.availableChoices', () {
    test('filters out choices whose gate is not satisfied', () {
      const node = StoryNode(
        id: 'n1',
        kind: NodeKind.fixed,
        narration: 'x',
        choices: [
          StoryChoice(label: 'Siempre disponible', targetNodeId: 'n2'),
          StoryChoice(
            label: 'Requiere nivel 3',
            targetNodeId: 'n3',
            gate: MinLevelGate(3),
          ),
        ],
      );

      final available = node.availableChoices(_character);
      expect(available, hasLength(1));
      expect(available.single.label, 'Siempre disponible');
    });

    test('preserves authored order among available choices', () {
      const node = StoryNode(
        id: 'n1',
        kind: NodeKind.fixed,
        choices: [
          StoryChoice(label: 'A', targetNodeId: 'a'),
          StoryChoice(label: 'B', targetNodeId: 'b'),
          StoryChoice(label: 'C', targetNodeId: 'c'),
        ],
      );
      expect(
        node.availableChoices(_character).map((c) => c.label),
        ['A', 'B', 'C'],
      );
    });
  });

  group('StoryNode.fromJson', () {
    test('parses a fixed node with choices and effects', () {
      final node = StoryNode.fromJson('beat_1', {
        'kind': 'fixed',
        'narration': 'El sendero se abre.',
        'choices': [
          {
            'label': 'Ir al templo',
            'target': 'beat_2',
            'effects': [
              {'type': 'flag', 'key': 'salio_de_la_aldea', 'value': true},
            ],
          },
        ],
      });

      expect(node.id, 'beat_1');
      expect(node.kind, NodeKind.fixed);
      expect(node.narration, 'El sendero se abre.');
      expect(node.choices, hasLength(1));
      expect(node.choices.single.targetNodeId, 'beat_2');
      expect(node.choices.single.effects.single.type, StateDeltaType.flag);
    });

    test('parses a generative node with a generation instruction', () {
      final node = StoryNode.fromJson('beat_2', {
        'kind': 'generative',
        'generation_instruction': 'Reconducí hacia el templo.',
        'allows_freeform': true,
      });

      expect(node.kind, NodeKind.generative);
      expect(node.generationInstruction, 'Reconducí hacia el templo.');
      expect(node.allowsFreeform, isTrue);
      expect(node.choices, isEmpty);
    });

    test('defaults kind to fixed when omitted', () {
      final node = StoryNode.fromJson('beat_x', {'narration': 'x'});
      expect(node.kind, NodeKind.fixed);
    });
  });
}
