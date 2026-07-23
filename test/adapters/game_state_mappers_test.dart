import 'package:aetherbook/adapters/persistence/game_state_mappers.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('characterToRow / characterFromRow', () {
    test('round-trips a character through row shape', () {
      const character = Character(
        name: 'Discípulo',
        level: 2,
        exp: 150,
        attributes: {'espiritu': 3, 'cuerpo': 4},
        resources: {'qi': 8},
        flags: {'conoció_al_anciano': true},
      );

      final row = characterToRow('session-1', character);
      expect(row['session_id'], 'session-1');
      expect(row['name'], 'Discípulo');
      expect(row['level'], 2);

      final restored = characterFromRow(row);
      expect(restored.name, character.name);
      expect(restored.level, character.level);
      expect(restored.exp, character.exp);
      expect(restored.attributes, character.attributes);
      expect(restored.resources, character.resources);
      expect(restored.flags, character.flags);
    });

    test('characterFromRow defaults missing jsonb maps to empty', () {
      final restored = characterFromRow({
        'name': 'X',
        'level': 1,
        'exp': 0,
        'attributes': null,
        'resources': null,
        'flags': null,
      });
      expect(restored.attributes, isEmpty);
      expect(restored.resources, isEmpty);
      expect(restored.flags, isEmpty);
    });
  });

  group('resolutionToJson', () {
    test('returns null for a null resolution (opening turn)', () {
      expect(resolutionToJson(null), isNull);
    });

    test('serializes every field of a resolution', () {
      const resolution = ActionResolution(
        outcome: ActionOutcome.criticalSuccess,
        attribute: 3,
        modifiers: 1,
        roll: 20,
        difficulty: 12,
        total: 24,
        isNatural20: true,
        isNatural1: false,
      );

      final json = resolutionToJson(resolution)!;
      expect(json['outcome'], 'criticalSuccess');
      expect(json['total'], 24);
      expect(json['isNatural20'], true);
      expect(json['isNatural1'], false);
    });
  });

  group('turnToRow / turnFromRow', () {
    test('turnToRow includes the resolved mechanics as jsonb', () {
      final row = turnToRow(
        sessionId: 'session-1',
        turnIndex: 2,
        playerAction: 'meditar',
        resolution: const ActionResolution(
          outcome: ActionOutcome.success,
          attribute: 2,
          modifiers: 0,
          roll: 10,
          difficulty: 12,
          total: 12,
          isNatural20: false,
          isNatural1: false,
        ),
        narration: 'Meditás en calma.',
        tone: 'sereno',
        suggestedChoices: const ['Seguir', 'Detenerte'],
      );

      expect(row['session_id'], 'session-1');
      expect(row['turn_index'], 2);
      expect(row['player_action'], 'meditar');
      expect(row['narration'], 'Meditás en calma.');
      expect((row['resolved_mechanics'] as Map)['outcome'], 'success');
      expect(row['suggested_choices'], ['Seguir', 'Detenerte']);
    });

    test('turnToRow stores null resolved_mechanics for the opening turn', () {
      final row = turnToRow(
        sessionId: 'session-1',
        turnIndex: 0,
        playerAction: '',
        resolution: null,
        narration: 'El sendero se abre.',
        tone: 'épico',
        suggestedChoices: const ['Meditar', 'Explorar'],
      );
      expect(row['resolved_mechanics'], isNull);
    });

    test('turnFromRow reconstructs a Turn from a row', () {
      final turn = turnFromRow({
        'turn_index': 3,
        'player_action': 'explorar',
        'narration': 'Avanzás por el sendero.',
        'suggested_choices': ['Seguir', 'Volver'],
      });
      expect(turn.index, 3);
      expect(turn.playerAction, 'explorar');
      expect(turn.narration, 'Avanzás por el sendero.');
      expect(turn.suggestedChoices, ['Seguir', 'Volver']);
    });

    test('turnFromRow defaults missing suggested_choices to empty', () {
      final turn = turnFromRow({
        'turn_index': 0,
        'player_action': '',
        'narration': 'x',
      });
      expect(turn.suggestedChoices, isEmpty);
    });
  });
}
