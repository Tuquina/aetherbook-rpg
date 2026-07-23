import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/adapters/narrator/narrator_json_parser.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/free_action_classification.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:flutter_test/flutter_test.dart';

const _character = Character(
  name: 'Discípulo',
  level: 1,
  exp: 0,
  attributes: {'espiritu': 2},
  resources: {'qi': 10},
);

const _world = World(
  slug: 'xianxia',
  name: 'El Sendero del Qi',
  theme: 'xianxia',
  tone: 'épico',
  systemPrompt: '',
  imageStyleSuffix: 'arte xianxia',
  defaultDifficulty: 12,
  criticalMargin: 5,
  primaryAttribute: 'espiritu',
  startingCharacter: _character,
  seedNarration: 'Comienza el sendero.',
  seedChoices: ['Meditar', 'Explorar', 'Leer'],
);

ActionResolution _resolution(ActionOutcome outcome) => ActionResolution(
      outcome: outcome,
      attributeKey: 'espiritu',
      attribute: 2,
      modifiers: 0,
      roll: 10,
      difficulty: 12,
      total: 12,
      isNatural20: false,
      isNatural1: false,
    );

void main() {
  group('parseNarratorJson (tolerant parser)', () {
    test('parses a clean JSON object', () {
      const raw = '{"narration":"Hola",'
          '"suggested_choices":[{"id":"a","label":"A"},{"id":"b","label":"B"}],'
          '"proposed_state_deltas":[{"type":"exp","key":"exp","value":10,'
          '"operation":"increment","reason":"porque sí"}],'
          '"image_prompt":"algo","tone":"tenso",'
          '"memory_facts":["prometió algo"],"node_status":"ready_to_exit"}';
      final r = parseNarratorJson(raw);
      expect(r.narration, 'Hola');
      expect(r.suggestedChoices.map((c) => c.label), ['A', 'B']);
      expect(r.stateDeltas.single.type, StateDeltaType.exp);
      expect(r.stateDeltas.single.reason, 'porque sí');
      expect(r.tone, 'tenso');
      expect(r.memoryFacts, ['prometió algo']);
      expect(r.nodeStatus, NodeStatus.readyToExit);
    });

    test('parses a choice with intent and expected_check', () {
      const raw = '{"narration":"x","suggested_choices":[{"id":"c",'
          '"label":"Investigar","intent":"investigate",'
          '"expected_check":{"attribute":"agudeza","difficulty_id":"standard"}}]}';
      final r = parseNarratorJson(raw);
      final choice = r.suggestedChoices.single;
      expect(choice.intent, ActionIntent.investigate);
      expect(choice.expectedCheck!.attribute, 'agudeza');
      expect(choice.expectedCheck!.difficultyId, 'standard');
    });

    test('strips ```json fences', () {
      const raw = '```json\n{"narration":"Con fence","suggested_choices":[]}\n```';
      final r = parseNarratorJson(raw);
      expect(r.narration, 'Con fence');
    });

    test('ignores surrounding prose and grabs the object', () {
      const raw = 'Claro, aquí tienes: {"narration":"Limpio",'
          '"suggested_choices":[]} ¡espero que sirva!';
      final r = parseNarratorJson(raw);
      expect(r.narration, 'Limpio');
    });

    test('maps unrecognised delta types to unknown', () {
      const raw = '{"narration":"x","proposed_state_deltas":'
          '[{"type":"teleport","key":"k","value":1}]}';
      final r = parseNarratorJson(raw);
      expect(r.stateDeltas.single.type, StateDeltaType.unknown);
    });

    test('defaults node_status to active and memory_facts to empty', () {
      final r = parseNarratorJson('{"narration":"x"}');
      expect(r.nodeStatus, NodeStatus.active);
      expect(r.memoryFacts, isEmpty);
    });

    test('throws on broken JSON', () {
      expect(
        () => parseNarratorJson('{"narration": "sin cerrar" '),
        throwsA(isA<NarratorParseException>()),
      );
    });

    test('throws when narration is missing', () {
      expect(
        () => parseNarratorJson('{"suggested_choices":[]}'),
        throwsA(isA<NarratorParseException>()),
      );
    });
  });

  group('FakeNarratorAdapter', () {
    const fake = FakeNarratorAdapter(latency: Duration.zero);

    test('returns the world seed on the opening turn (null resolution)', () async {
      final r = await fake.narrate(const NarratorRequest(
        world: _world,
        character: _character,
        playerAction: '',
        resolution: null,
      ));
      expect(r.narration, contains('sendero'));
      expect(r.suggestedChoices, isNotEmpty);
    });

    test('fulfils the contract for every outcome band', () async {
      for (final outcome in ActionOutcome.values) {
        final r = await fake.narrate(NarratorRequest(
          world: _world,
          character: _character,
          playerAction: 'forzar la puerta',
          resolution: _resolution(outcome),
        ));
        expect(r.narration, isNotEmpty, reason: '$outcome narration');
        expect(r.suggestedChoices.length, greaterThanOrEqualTo(2),
            reason: '$outcome choices');
        expect(r.tone, isNotEmpty, reason: '$outcome tone');
        expect(r.imagePrompt, contains('arte xianxia'),
            reason: '$outcome image style suffix appended');
      }
    });

    test('escapes arbitrary player action text safely', () async {
      final r = await fake.narrate(NarratorRequest(
        world: _world,
        character: _character,
        playerAction: 'decir "hola" y usar \\ barras {llaves}',
        resolution: _resolution(ActionOutcome.success),
      ));
      expect(r.narration, contains('"hola"'));
    });

    test('a successful outcome proposes an exp delta', () async {
      final r = await fake.narrate(NarratorRequest(
        world: _world,
        character: _character,
        playerAction: 'meditar',
        resolution: _resolution(ActionOutcome.success),
      ));
      expect(
        r.stateDeltas.any((d) => d.type == StateDeltaType.exp),
        isTrue,
      );
      expect(
        r.stateDeltas.every((d) => d.toStateDelta() != null),
        isTrue,
        reason: 'every canned delta declares a supported operation',
      );
    });
  });
}
