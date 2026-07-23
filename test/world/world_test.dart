import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> baseWorldJson() => {
        'slug': 'xianxia_lianshu',
        'name': 'Los nombres que devora el cielo',
        'starting_character': {
          'name': 'Protagonista',
          'level': 1,
          'exp': 0,
          'attributes': {'cuerpo': 3, 'agudeza': 2, 'espiritu': 2, 'presencia': 1},
        },
      };

  group('World resource formulas', () {
    test('computes starting resources from a per-attribute formula', () {
      final json = baseWorldJson()
        ..['resources'] = {
          'vitality': {'base': 8, 'per_attribute': {'cuerpo': 2}},
          'qi': {'base': 4, 'per_attribute': {'espiritu': 2}},
        };
      final world = World.fromJson(json);

      // 8 + cuerpo(3)*2 = 14; 4 + espiritu(2)*2 = 8.
      expect(world.startingCharacter.resource('vitality'), 14);
      expect(world.startingCharacter.resource('qi'), 8);
    });

    test('a flat resource declared on starting_character still works without a formula', () {
      final json = baseWorldJson();
      (json['starting_character'] as Map)['resources'] = {'salud': 20};
      final world = World.fromJson(json);
      expect(world.startingCharacter.resource('salud'), 20);
    });

    test('maxResource reports the formula-derived ceiling for a character', () {
      final json = baseWorldJson()
        ..['resources'] = {
          'vitality': {'base': 8, 'per_attribute': {'cuerpo': 2}},
        };
      final world = World.fromJson(json);
      expect(
        world.maxResource('vitality', world.startingCharacter),
        14,
      );
    });

    test('maxResource is null for a resource with no declared formula', () {
      final world = World.fromJson(baseWorldJson());
      expect(world.maxResource('salud', world.startingCharacter), isNull);
    });
  });

  group('World meter definitions', () {
    test('initializes stored (non-derived) meters to their declared initial value', () {
      final json = baseWorldJson()
        ..['meters'] = {
          'karma': {'min': -3, 'max': 3, 'initial': 0},
          'ledger_debt': {'min': 0},
        };
      final world = World.fromJson(json);
      expect(world.startingCharacter.meter('karma'), 0);
      expect(world.startingCharacter.meter('ledger_debt'), 0);
    });

    test('does not store an initial value for a derived meter', () {
      final json = baseWorldJson()
        ..['meters'] = {
          'evidence_count': {
            'derived_from_flags': ['evidence_a', 'evidence_b'],
          },
        };
      final world = World.fromJson(json);
      expect(world.startingCharacter.meters.containsKey('evidence_count'), isFalse);
    });

    test('meterValue resolves a derived meter from the character\'s flags', () {
      final json = baseWorldJson()
        ..['meters'] = {
          'evidence_count': {
            'derived_from_flags': ['evidence_a', 'evidence_b'],
          },
        };
      final world = World.fromJson(json);
      final character = world.startingCharacter.copyWith(
        flags: {'evidence_a': true},
      );
      expect(world.meterValue('evidence_count', character), 1);
    });

    test('meterValue falls back to the raw stored meter when undeclared', () {
      final world = World.fromJson(baseWorldJson());
      final character = world.startingCharacter.copyWith(
        meters: {'undeclared_counter': 7},
      );
      expect(world.meterValue('undeclared_counter', character), 7);
    });
  });

  group('World ranks', () {
    test('parses milestone-gated ranks from JSON', () {
      final json = baseWorldJson()
        ..['ranks'] = [
          {'id': 'aliento_velado', 'level': 1, 'exp_required': 0},
          {
            'id': 'meridiano_abierto',
            'level': 2,
            'exp_required': 5,
            'milestone_flag': 'reached_casa_de_tinta',
          },
        ];
      final world = World.fromJson(json);
      expect(world.ranks, hasLength(2));
      expect(world.ranks.last.milestoneFlag, 'reached_casa_de_tinta');
    });

    test('currentRank finds the rank matching the character\'s level', () {
      final json = baseWorldJson()
        ..['ranks'] = [
          {'id': 'aliento_velado', 'level': 1, 'exp_required': 0},
          {'id': 'meridiano_abierto', 'level': 2, 'exp_required': 5},
        ];
      final world = World.fromJson(json);
      final levelTwo = world.startingCharacter.copyWith(level: 2);
      expect(world.currentRank(levelTwo)?.id, 'meridiano_abierto');
    });

    test('currentRank is null for a world with no declared ranks', () {
      final world = World.fromJson(baseWorldJson());
      expect(world.currentRank(world.startingCharacter), isNull);
    });
  });

  group('World free-action classifier config', () {
    test('parses intent_keywords, risk_keywords and self_grant_patterns', () {
      final json = baseWorldJson()
        ..['resolution'] = {
          'intent_keywords': {
            'force': ['forzar', 'romper'],
          },
          'risk_keywords': {
            'high': ['a ciegas'],
          },
          'self_grant_patterns': ['me otorgo'],
        };
      final world = World.fromJson(json);
      expect(world.intentKeywords['force'], ['forzar', 'romper']);
      expect(world.riskKeywords['high'], ['a ciegas']);
      expect(world.selfGrantPatterns, ['me otorgo']);
    });

    test('defaults to empty when undeclared', () {
      final world = World.fromJson(baseWorldJson());
      expect(world.intentKeywords, isEmpty);
      expect(world.riskKeywords, isEmpty);
      expect(world.selfGrantPatterns, isEmpty);
    });
  });

  group('World story graph, npcs and techniques', () {
    test('parses a story graph and resolves its start node', () {
      final json = baseWorldJson()
        ..['graph'] = {
          'start_node': 'p1_barca_funeraria',
          'nodes': {
            'p1_barca_funeraria': {'narration': 'Primero vuelve el frío.'},
          },
        };
      final world = World.fromJson(json);
      expect(world.storyGraph, isNotNull);
      expect(world.storyGraph!.startNodeId, 'p1_barca_funeraria');
    });

    test('storyGraph is null when the world declares no graph', () {
      final world = World.fromJson(baseWorldJson());
      expect(world.storyGraph, isNull);
    });

    test('parses npcs and finds them by id', () {
      final json = baseWorldJson()
        ..['npcs'] = [
          {'id': 'lian_suyin', 'display_name': 'Lian Suyin', 'aliases': ['Suyin']},
        ];
      final world = World.fromJson(json);
      expect(world.npcs, hasLength(1));
      expect(world.npcById('lian_suyin').displayName, 'Lian Suyin');
    });

    test('npcById throws for an unknown id', () {
      final world = World.fromJson(baseWorldJson());
      expect(() => world.npcById('no_existe'), throwsArgumentError);
    });

    test('parses techniques and finds them by id', () {
      final json = baseWorldJson()
        ..['techniques'] = [
          {'id': 'paso_entre_trazos', 'cost_qi': 1, 'primary_attribute': 'agudeza'},
        ];
      final world = World.fromJson(json);
      expect(world.techniques, hasLength(1));
      expect(world.techniqueById('paso_entre_trazos').costQi, 1);
    });

    test('techniqueById throws for an unknown id', () {
      final world = World.fromJson(baseWorldJson());
      expect(() => world.techniqueById('no_existe'), throwsArgumentError);
    });
  });

  group('World opponents', () {
    test('parses opponents and finds them by id', () {
      final json = baseWorldJson()
        ..['opponents'] = [
          {'id': 'coro_blanco', 'display_name': 'Coro Blanco', 'guard': 4},
        ];
      final world = World.fromJson(json);
      expect(world.opponents, hasLength(1));
      expect(world.opponentById('coro_blanco').maxGuard, 4);
    });

    test('opponentById throws for an unknown id', () {
      final world = World.fromJson(baseWorldJson());
      expect(() => world.opponentById('no_existe'), throwsArgumentError);
    });
  });
}
