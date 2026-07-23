import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/ending.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/narrative/hub_activity.dart';
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
  group('FixedAnchorNode', () {
    test('availableChoices filters out choices whose gate is not satisfied', () {
      const node = FixedAnchorNode(
        id: 'n1',
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
      const node = FixedAnchorNode(
        id: 'n1',
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

    test('StoryNode.fromJson parses a fixed_anchor with choices, effects and reveals', () {
      final node = StoryNode.fromJson('c1_n03_coro_en_el_campanario', {
        'type': 'fixed_anchor',
        'narration': 'El sendero se abre.',
        'fixed_reveals': ['Siete personas ya fueron borradas.'],
        'forbidden_reveals': ['El ritual original distribuía recuerdos.'],
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

      expect(node, isA<FixedAnchorNode>());
      final anchor = node as FixedAnchorNode;
      expect(anchor.narration, 'El sendero se abre.');
      expect(anchor.fixedReveals, ['Siete personas ya fueron borradas.']);
      expect(anchor.forbiddenReveals, ['El ritual original distribuía recuerdos.']);
      expect(anchor.choices.single.targetNodeId, 'beat_2');
      expect(anchor.choices.single.effects.single.type, StateDeltaType.flag);
    });

    test('StoryNode.fromJson defaults to fixed_anchor when type is omitted', () {
      final node = StoryNode.fromJson('beat_x', {'narration': 'x'});
      expect(node, isA<FixedAnchorNode>());
    });
  });

  group('BoundedCorridorNode', () {
    test('parses goal, turn budget, fallback exit and guardrail lists', () {
      final node = StoryNode.fromJson('c1_n02_buscar_acceso', {
        'type': 'bounded_corridor',
        'goal': 'Obtener exactamente un access_token.',
        'turn_budget': 3,
        'fallback_exit': 'c1_n03_coro_en_el_campanario',
        'allowed_locations': ['Mercado de Nombres'],
        'allowed_npcs': ['Mei Ruo'],
        'allowed_obstacles': ['patrulla'],
        'forbidden_reveals': ['los siete cuerpos'],
      });

      expect(node, isA<BoundedCorridorNode>());
      final corridor = node as BoundedCorridorNode;
      expect(corridor.goal, 'Obtener exactamente un access_token.');
      expect(corridor.turnBudget, 3);
      expect(corridor.fallbackExitNodeId, 'c1_n03_coro_en_el_campanario');
      expect(corridor.allowedLocations, ['Mercado de Nombres']);
      expect(corridor.allowedNpcs, ['Mei Ruo']);
      expect(corridor.allowedObstacles, ['patrulla']);
      expect(corridor.forbiddenReveals, ['los siete cuerpos']);
    });

    test('isBudgetExhausted compares turns used against the budget', () {
      const corridor = BoundedCorridorNode(
        id: 'x',
        goal: 'g',
        turnBudget: 3,
        fallbackExitNodeId: 'y',
      );
      expect(corridor.isBudgetExhausted(2), isFalse);
      expect(corridor.isBudgetExhausted(3), isTrue);
      expect(corridor.isBudgetExhausted(4), isTrue);
    });

    test('availableChoices filters explicit exits by gate', () {
      const corridor = BoundedCorridorNode(
        id: 'x',
        goal: 'g',
        turnBudget: 3,
        fallbackExitNodeId: 'y',
        choices: [
          StoryChoice(label: 'Ruta A', targetNodeId: 'a'),
          StoryChoice(
            label: 'Ruta B (requiere nivel 2)',
            targetNodeId: 'b',
            gate: MinLevelGate(2),
          ),
        ],
      );
      expect(corridor.availableChoices(_character).map((c) => c.label), ['Ruta A']);
    });
  });

  group('StateHubNode', () {
    test('parses activities and exits', () {
      final node = StoryNode.fromJson('c1_n01_casa_de_tinta', {
        'type': 'state_hub',
        'activities': [
          {'id': 'descansar', 'label': 'Descansar y tratar heridas'},
          {
            'id': 'examinar_tablilla',
            'label': 'Examinar la tablilla en blanco',
            'repeatable': false,
          },
        ],
        'exits': [
          {'label': 'Ir al mercado', 'target': 'c1_n02_buscar_acceso'},
        ],
      });

      expect(node, isA<StateHubNode>());
      final hub = node as StateHubNode;
      expect(hub.activities, hasLength(2));
      expect(hub.activities.first.repeatable, isTrue);
      expect(hub.activities.last.repeatable, isFalse);
      expect(hub.exits.single.targetNodeId, 'c1_n02_buscar_acceso');
    });

    test('availableActivities and availableExits filter by gate', () {
      const hub = StateHubNode(
        id: 'hub',
        activities: [
          HubActivity(id: 'a', label: 'Siempre'),
          HubActivity(id: 'b', label: 'Requiere nivel 5', gate: MinLevelGate(5)),
        ],
        exits: [
          StoryChoice(label: 'Salir', targetNodeId: 'next'),
          StoryChoice(
            label: 'Atajo (requiere nivel 5)',
            targetNodeId: 'shortcut',
            gate: MinLevelGate(5),
          ),
        ],
      );
      expect(hub.availableActivities(_character).map((a) => a.id), ['a']);
      expect(hub.availableExits(_character).map((e) => e.label), ['Salir']);
    });
  });

  group('ResolutionNode', () {
    test('parses endings', () {
      final node = StoryNode.fromJson('c5_n03_ritual_final', {
        'type': 'resolution',
        'endings': [
          {
            'id': 'nuevo_pacto',
            'visible_choice': 'Abrir el Registro.',
            'hard_requirement': {'type': 'flag', 'key': 'evidence_original_covenant'},
          },
        ],
      });

      expect(node, isA<ResolutionNode>());
      final resolution = node as ResolutionNode;
      expect(resolution.endings.single.id, 'nuevo_pacto');
    });

    test('availableEndings filters by each ending\'s hard requirement', () {
      const resolution = ResolutionNode(
        id: 'ritual',
        endings: [
          Ending(id: 'always', visibleChoice: 'x'),
          Ending(
            id: 'needs_covenant',
            visibleChoice: 'y',
            hardRequirement: FlagGate('evidence_original_covenant'),
          ),
        ],
      );
      expect(
        resolution.availableEndings(_character).map((e) => e.id),
        ['always'],
      );
      final withCovenant = _character.copyWith(
        flags: {'evidence_original_covenant': true},
      );
      expect(
        resolution.availableEndings(withCovenant).map((e) => e.id),
        ['always', 'needs_covenant'],
      );
    });
  });
}
