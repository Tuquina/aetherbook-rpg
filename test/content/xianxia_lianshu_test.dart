// Loads the real xianxia_lianshu content asset — not a fake/fixture — and
// checks the structural criteria from the campaign bible §22.1 that are
// mechanical (not tone/prose, which needs a human read). This is Fase 7's
// acceptance test: the content must parse and be internally consistent
// against the engine, even though nothing plays it yet (Fase 8).
import 'dart:convert';
import 'dart:io';

import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/story_graph_test_helpers.dart';

World _loadWorld() {
  final raw =
      File('assets/worlds/xianxia_lianshu.json').readAsStringSync();
  return World.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// The full node index this campaign declares (campaign-bible §9.3, minus
/// `p0_creacion` which isn't a graph node — plus the `x_fuga_confirmacion`
/// connector).
const _expectedNodeTypes = <String, Type>{
  'p1_barca_funeraria': FixedAnchorNode,
  'p2_bajo_el_puente': BoundedCorridorNode,
  'c1_n01_casa_de_tinta': StateHubNode,
  'c1_n02_buscar_acceso': BoundedCorridorNode,
  'c1_n03_coro_en_el_campanario': FixedAnchorNode,
  'c2_n01_entrada_al_pabellon': BoundedCorridorNode,
  'c2_n02_salon_quieto': FixedAnchorNode,
  'c2_n03_archivo_de_la_lluvia': FixedAnchorNode,
  'c2_n04_la_fuga': BoundedCorridorNode,
  'c3_n01_ciudad_que_olvida': FixedAnchorNode,
  'x_fuga_confirmacion': FixedAnchorNode,
  'c3_n02_audiencia': FixedAnchorNode,
  'c3_n03_primera_ola': FixedAnchorNode,
  'c4_n01_pozo_de_los_ecos': FixedAnchorNode,
  'c4_n02_preparativos': StateHubNode,
  'c5_n01_descenso': BoundedCorridorNode,
  'c5_n02_ultima_guardia': FixedAnchorNode,
  'c5_n03_ritual_final': ResolutionNode,
  'e_epilogo': ResolutionNode,
};

void main() {
  group('xianxia_lianshu.json — root config', () {
    test('parses without throwing', () {
      expect(_loadWorld, returnsNormally);
    });

    test('critical margin matches campaign-bible §6.4 (total >= DC + 8)', () {
      expect(_loadWorld().criticalMargin, 8);
    });

    test('default difficulty matches the "Estándar" band (§6.3)', () {
      expect(_loadWorld().defaultDifficulty, 12);
    });

    test('declares the four campaign attributes', () {
      expect(
        _loadWorld().attributeKeys,
        unorderedEquals(['cuerpo', 'agudeza', 'espiritu', 'presencia']),
      );
    });
  });

  group('xianxia_lianshu.json — chargen (§5.3/§5.4/§7.1)', () {
    test('declares the four origins', () {
      expect(_loadWorld().origins, hasLength(4));
    });

    test('declares the four vows', () {
      expect(_loadWorld().vows, hasLength(4));
    });

    test('declares the four milestone-gated ranks', () {
      final ranks = _loadWorld().ranks;
      expect(ranks, hasLength(4));
      expect(ranks.map((r) => r.id), contains('nombre_propio'));
    });
  });

  group('xianxia_lianshu.json — cast, opponents, techniques', () {
    test('declares the six recurring named NPCs', () {
      expect(_loadWorld().npcs, hasLength(6));
    });

    test('declares the five abstract opponents', () {
      expect(_loadWorld().opponents, hasLength(5));
    });

    test('declares the nine techniques (4 initial + forbidden + 4 final)', () {
      expect(_loadWorld().techniques, hasLength(9));
    });
  });

  group('xianxia_lianshu.json — resources and meters (§5.5/§8.1)', () {
    test('vitality and qi formulas match §5.5', () {
      final world = _loadWorld();
      final character = world.startingCharacter;
      // 8 + cuerpo(1)*2 = 10; 4 + espiritu(1)*2 = 6.
      expect(world.maxResource('vitality', character), 10);
      expect(world.maxResource('qi', character), 6);
    });

    test('evidence_count is derived from the four evidence flags', () {
      final world = _loadWorld();
      final withTwo = world.startingCharacter.copyWith(
        flags: {'evidence_forged_seal': true, 'evidence_donors_alive': true},
      );
      expect(world.meterValue('evidence_count', withTwo), 2);
    });

    test('karma is bounded to [-3, 3]', () {
      final world = _loadWorld();
      final over = world.startingCharacter.copyWith(meters: {'karma': 99});
      expect(world.meterValue('karma', over), 3);
    });
  });

  group('xianxia_lianshu.json — story graph (campaign-bible §22.1)', () {
    test('starts at p1_barca_funeraria (p0_creacion is chargen, not a graph node)', () {
      expect(_loadWorld().storyGraph!.startNodeId, 'p1_barca_funeraria');
    });

    test('declares every expected node id with its correct type', () {
      final graph = _loadWorld().storyGraph!;
      expect(graph.nodes.keys, unorderedEquals(_expectedNodeTypes.keys));
      for (final entry in _expectedNodeTypes.entries) {
        expect(
          graph.nodeById(entry.key).runtimeType,
          entry.value,
          reason: 'node ${entry.key}',
        );
      }
    });

    test('has no dangling choice/exit/fallback references', () {
      expect(_loadWorld().storyGraph!.unknownTargetIds(), isEmpty);
    });

    test('every node reaches the ritual (campaign-bible §22.1); the epilogue '
        'is reached procedurally after resolution, not via a graph edge', () {
      final graph = _loadWorld().storyGraph!;
      final reachable = reachableFrom(graph);
      final expectedExceptEpilogue = {..._expectedNodeTypes.keys}
        ..remove('e_epilogo');
      expect(reachable, unorderedEquals(expectedExceptEpilogue));
    });

    test('every rank\'s milestone_flag is actually set somewhere in the graph', () {
      final world = _loadWorld();
      final setFlags = allTrueFlagKeysSet(world.storyGraph!);
      for (final rank in world.ranks) {
        final milestone = rank.milestoneFlag;
        if (milestone == null) continue;
        expect(
          setFlags,
          contains(milestone),
          reason:
              'rank ${rank.id} requires "$milestone", but no choice/activity in '
              'the graph ever sets it — that rank could never be reached',
        );
      }
    });

    test('every bounded_corridor stays within a 3-turn budget', () {
      final graph = _loadWorld().storyGraph!;
      for (final node in graph.nodes.values) {
        if (node is BoundedCorridorNode) {
          expect(
            node.turnBudget,
            lessThanOrEqualTo(3),
            reason: '${node.id} exceeds the campaign\'s corridor budget',
          );
        }
      }
    });
  });

  group('xianxia_lianshu.json — endings and final technique (§16, §7.5)', () {
    ResolutionNode ritual() =>
        _loadWorld().storyGraph!.nodeById('c5_n03_ritual_final')
            as ResolutionNode;

    test('declares the 5 mechanical endings plus the fugitive early exit', () {
      // nuevo_pacto_fracturado is the 7th possible `ending_id` (campaign-bible
      // §16.1) but isn't a separately *chosen* ending — it's only reachable
      // as nuevo_pacto's own failure fallback, verified below.
      expect(ritual().endings, hasLength(6));
      expect(
        ritual().endings.map((e) => e.id),
        containsAll([
          'nuevo_pacto',
          'portador_del_margen',
          'cielo_roto',
          'guardian_del_registro',
          'soberano_sin_nombre',
          'fugitivo_degradado',
        ]),
      );
    });

    test('fugitivo_degradado is only available once the flight is confirmed', () {
      final ending =
          ritual().endings.firstWhere((e) => e.id == 'fugitivo_degradado');
      const noFlight = Character(
        name: 'x',
        level: 1,
        exp: 0,
        attributes: {},
        resources: {},
      );
      expect(ending.isAvailableTo(noFlight), isFalse);
      expect(
        ending.isAvailableTo(noFlight.copyWith(flags: {'fled_valley_confirmed': true})),
        isTrue,
      );
    });

    test('every other ending is unavailable once flight is confirmed', () {
      final confirmed = const Character(
        name: 'x',
        level: 1,
        exp: 0,
        attributes: {},
        resources: {},
      ).copyWith(
        flags: {
          'fled_valley_confirmed': true,
          'evidence_original_covenant': true,
        },
        meters: {'ledger_debt': 3},
      );
      for (final ending in ritual().endings) {
        if (ending.id == 'fugitivo_degradado') continue;
        expect(
          ending.isAvailableTo(confirmed),
          isFalse,
          reason: '${ending.id} should be excluded once flight is confirmed',
        );
      }
    });

    test('nuevo_pacto\'s failure redirects to portador or fracturado by ledger_debt', () {
      final ending = ritual().endings.firstWhere((e) => e.id == 'nuevo_pacto');
      const low = Character(
        name: 'x',
        level: 1,
        exp: 0,
        attributes: {},
        resources: {},
      );
      expect(ending.failureEndingIdFor(low), 'portador_del_margen');
      expect(
        ending.failureEndingIdFor(low.copyWith(meters: {'ledger_debt': 4})),
        'nuevo_pacto_fracturado',
      );
    });

    test('declares the 4 final-technique priority rules, ending in a catch-all', () {
      final rules = ritual().finalTechniqueRules;
      expect(rules, hasLength(4));
      expect(rules.last.techniqueId, 'yo_me_nombro');
      const anyCharacter = Character(
        name: 'x',
        level: 1,
        exp: 0,
        attributes: {},
        resources: {},
      );
      expect(rules.last.isSatisfiedBy(anyCharacter), isTrue);
    });
  });

  group('xianxia_lianshu.json — epilogue (§16.8)', () {
    test('e_epilogo declares beats for all 5 movements and no endings', () {
      final epilogue =
          _loadWorld().storyGraph!.nodeById('e_epilogo') as ResolutionNode;
      expect(epilogue.endings, isEmpty);
      final movements = epilogue.epilogueBeats.map((b) => b.movement).toSet();
      expect(
        movements,
        {
          'la_mañana_siguiente',
          'una_persona_afectada',
          'la_nueva_regla',
          'el_protagonista',
          'la_tablilla',
        },
      );
    });

    test('every movement has at least one catch-all (AlwaysGate) beat', () {
      final epilogue =
          _loadWorld().storyGraph!.nodeById('e_epilogo') as ResolutionNode;
      const empty = Character(
        name: 'x',
        level: 1,
        exp: 0,
        attributes: {},
        resources: {},
      );
      final movements = epilogue.epilogueBeats.map((b) => b.movement).toSet();
      for (final movement in movements) {
        final beats =
            epilogue.epilogueBeats.where((b) => b.movement == movement);
        expect(
          beats.any((b) => b.isSatisfiedBy(empty)),
          isTrue,
          reason: 'movement "$movement" has no beat satisfied by a bare character',
        );
      }
    });
  });
}
