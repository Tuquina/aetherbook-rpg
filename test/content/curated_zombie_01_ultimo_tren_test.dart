// Loads the real curated_zombie_01_ultimo_tren.json content asset — not a
// fake/fixture — and checks structural criteria from the story bible
// (brainstorming-worlds/Historia-Completa-01...): no dangling references,
// every reachable outcome carries authored prose (this campaign makes zero
// AI calls), and the campaign-level contract (ai_runtime_required: false,
// free_text_actions: false) actually holds. Grown chapter by chapter as the
// content is authored — `_expectedNodeIds` only lists nodes that exist so
// far.
import 'dart:convert';
import 'dart:io';

import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/story_graph_test_helpers.dart';

World _loadWorld() {
  final raw =
      File('assets/worlds/curated_zombie_01_ultimo_tren.json').readAsStringSync();
  return World.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Nodes authored so far (grows as chapters are added). Prólogo + the start
/// of Capítulo I (§9.4 of the story bible index) — includes a few
/// engine-level connector nodes (`p1_frente2_after_*`, `p1_alarm_close_*`,
/// `p1_combat_tutorial`) the bible's node table doesn't list separately
/// because it describes "Decisión 2" as a sub-screen of `p1_alarma_camara`,
/// not a distinct id — splitting them keeps every branch fully authored
/// with no runtime "guess which flag is missing" logic.
const _expectedNodeIds = <String>{
  'p0_perfil',
  'p0_postura',
  'p1_alarma_camara',
  'p1_frente2_after_puerta',
  'p1_frente2_after_medicina',
  'p1_frente2_after_diesel',
  'p1_alarm_close_medicina_pendiente',
  'p1_alarm_close_diesel_pendiente',
  'p1_alarm_close_medicina_pendiente_2',
  'p1_pre_close',
  'p1_combat_tutorial',
  'p1_alarm_close',
  'p2_voz_aurora',
  'c1_n01_consejo',
  'c1_n01b_combustible',
  'c1_n01b_divulgar',
  'c1_n01c_mandato',
  'c1_n01d_confesion_parcial',
  'c1_n02_elegir_equipo',
  'c1_n02b_segundo',
  'c1_n03_inventario',
  'c1_n03b_segundo_paquete',
  'c1_n04_salir',
  'c2_n01_bifurcacion',
  'c2_n02_autopista',
  'c2_n02b_resultado_rescate',
  'c2_n02c_rescate_limpio',
  'c2_n02c_rescate_ruidoso',
  'c2_n03_barrio_bajo',
  'c2_n03b_farmacia',
  'c2_n03c_supermercado',
  'c2_n03d_ambos',
  'c2_n04_deposito_vial',
  'c2_n04b_cisterna',
  'c2_n04c_gabinete',
  'c2_n05_noche_taller',
  'c2_n05b_conversacion',
  'c2_n05c_flecha',
  'c3_n01_subestacion',
  'c3_n01b_encuentro',
  'c3_n02_yago_herido',
  'c3_n03_pacto_silos',
  'c3_n04_ataque_granero',
  'c3_n04b_resultado',
  'c4_n01_entrada_san_gregorio',
  'c4_n01b_luz_roja',
  'c4_n02_supermercado_mudo',
  'c4_n02b_deposito',
  'c4_n02c_video',
  'c4_n03_campanario',
  'c4_n04_estacion_central',
  'c4_n04b_operaciones',
  'c4_n05_torre_senales',
  'c4_n05b_radio',
  'c4_n05c_cierre',
  'c5_n01_tunel_17',
  'c5_n02_vagon_equipajes',
  'c5_n02b_prioridad',
  'c5_n03_registro_negro',
  'c5_n04_elena_rojo',
  'c5_n05_confesion_abril',
  'c5_n06_abrir_via',
  'c5_n06b_exito',
  'c6_n01_regreso_camara',
  'c6_n02_verdad_publica',
  'c6_n02b_c17',
  'c6_n03_lista_veinte',
  'c6_n04_noche_motin',
  'c6_n04b_resultado',
  'c7_n01_puente_quebrado',
  'c7_n01b_girar',
  'c7_n01c_exito',
  'c7_n02_rele_manual',
  'c7_n02b_energia',
  'c7_n02c_transmision',
  'c7_n03_horda_vias',
  'c7_n03b_segundo_frente',
  'c7_n04_ultimo_relevo',
  'c7_n04b_saul_sacrificio',
  'c7_n05_senal_verde',
  'c8_n01_llegada_aurora',
  'c8_n02_precio_diesel',
  'c8_n03_capitana_davila',
  'c8_n04_ocho_minutos',
  'c8_n04b_cierre',
  'c9_n01_golpes_vagon',
  'c9_n02b_incendio',
  'c9_n02_brote_aurora',
  'c9_n02c_resultado',
  'c9_n03_separar_vagones',
  'c9_n04_quien_cierra_puerta',
  'c10_n01_anden_dividido',
  'c10_n02_decision_final',
  'end_faro_sur',
  'end_los_que_suben',
  'end_linea_vivos',
  'end_tomar_aurora',
  'end_quedarse',
  'end_ultimo_relevo',
  'end_ultimo_relevo_resultado',
  'fail_anden',
  'fail_infeccion',
  'epilogo',
};

/// No pending chapter starts anymore — the campaign is fully authored,
/// prólogo through epílogo. Kept as an empty const (rather than deleted) so
/// the dangling-reference test below still documents its intent.
const _pendingChapterStarts = <String>{};

void main() {
  group('curated_zombie_01_ultimo_tren.json — root config', () {
    test('parses without throwing', () {
      expect(_loadWorld, returnsNormally);
    });

    test('declares zero AI runtime and zero free text (story bible §25.10)', () {
      final world = _loadWorld();
      expect(world.aiRuntimeRequired, isFalse);
      expect(world.allowFreeText, isFalse);
    });

    test('critical margin and default difficulty match §6.3/§6.4', () {
      final world = _loadWorld();
      expect(world.criticalMargin, 5);
      expect(world.defaultDifficulty, 12);
    });

    test('declares the four campaign attributes (§6.1)', () {
      expect(
        _loadWorld().attributeKeys,
        unorderedEquals(['cuerpo', 'tecnica', 'instinto', 'humanidad']),
      );
    });

    test('widens relationship bounds to [-3, 3] with magnitude cap 3 (§8.2)', () {
      final world = _loadWorld();
      expect(world.relationshipMin, -3);
      expect(world.relationshipMax, 3);
      expect(world.relationshipMagnitudeCap, 3);
    });

    test('chargen has no free attribute point and relabels the vow step (§5.2/§5.3)', () {
      final world = _loadWorld();
      expect(world.hasFreeAttributePoint, isFalse);
      expect(world.chargenVowLabel, 'Recuerdo conservado');
    });
  });

  group('curated_zombie_01_ultimo_tren.json — chargen (§5.2/§5.3)', () {
    test('declares the three fixed survival profiles, each summing to 9 points', () {
      final origins = _loadWorld().origins;
      expect(origins, hasLength(3));
      for (final origin in origins) {
        final sum = origin.baseAttributes.values.fold(0, (a, b) => a + b);
        expect(sum, 9, reason: '${origin.id} should sum to 9 points');
      }
    });

    test('declares the three memory items as vows (§5.3)', () {
      expect(_loadWorld().vows, hasLength(3));
      expect(
        _loadWorld().vows.map((v) => v.id),
        containsAll(['reloj_elena', 'boleto_abril', 'placa_operador']),
      );
    });

    test('declares the five milestone-gated ranks (§7.2)', () {
      final ranks = _loadWorld().ranks;
      expect(ranks, hasLength(5));
      expect(ranks.map((r) => r.id),
          ['mantenedor', 'explorador', 'referente', 'conductor', 'fundador']);
    });
  });

  group('curated_zombie_01_ultimo_tren.json — health formula (§6.6)', () {
    test('max health = 10 + cuerpo * 2', () {
      final world = _loadWorld();
      final character = world.startingCharacter.copyWith(attributes: {'cuerpo': 3});
      expect(world.maxResource('health', character), 16);
    });
  });

  group('curated_zombie_01_ultimo_tren.json — story graph', () {
    test('starts at p0_perfil', () {
      expect(_loadWorld().storyGraph!.startNodeId, 'p0_perfil');
    });

    test('every authored node is a FixedAnchorNode (no AI-driven corridors/hubs yet)', () {
      final graph = _loadWorld().storyGraph!;
      for (final id in _expectedNodeIds) {
        expect(graph.nodeById(id), isA<FixedAnchorNode>(), reason: id);
      }
    });

    test('every dangling reference is a known not-yet-written chapter start', () {
      final dangling = _loadWorld().storyGraph!.unknownTargetIds();
      expect(dangling, _pendingChapterStarts);
    });

    test('every authored node is reachable from the start node', () {
      final graph = _loadWorld().storyGraph!;
      expect(reachableFrom(graph), _expectedNodeIds);
    });

    test('every reachable outcome carries its own authored resultText (zero AI calls)', () {
      final graph = _loadWorld().storyGraph!;
      final missing = choicesMissingResultText(graph)
          .where((m) => !_pendingChapterStarts.any(m.startsWith))
          .toList();
      expect(missing, isEmpty, reason: missing.join('\n'));
    });

    test('the three origin-gated equip choices in p0_perfil are mutually exclusive', () {
      final node = _loadWorld().storyGraph!.nodeById('p0_perfil') as FixedAnchorNode;
      expect(node.choices, hasLength(3));
      final gates = node.choices.map((c) => c.gate).toSet();
      expect(gates, hasLength(3), reason: 'each origin choice must have a distinct gate');
    });
  });

  group('curated_zombie_01_ultimo_tren.json — property invariants (story bible §30.5)', () {
    Character bareCharacter() => const Character(
          name: 'Damián',
          level: 1,
          exp: 0,
          attributes: {},
          resources: {},
        );

    StoryChoice endingChoice(String labelSubstring) {
      final node = _loadWorld().storyGraph!.nodeById('c10_n02_decision_final')
          as FixedAnchorNode;
      return node.choices.firstWhere((c) => c.label.contains(labelSubstring));
    }

    test('"proponer una línea regional" is unreachable without silos_pact', () {
      final choice = endingChoice('línea regional');
      expect(choice.isAvailableTo(bareCharacter()), isFalse);
    });

    test('"proponer una línea regional" becomes available once every hard requirement is met', () {
      final choice = endingChoice('línea regional');
      final ready = bareCharacter().copyWith(
        flags: {'silos_pact': true, 'diesel_deal': true},
        meters: {'repair_progress': 4, 'community_trust': 0, 'humanity_axis': 2},
      );
      expect(choice.isAvailableTo(ready), isTrue);
    });

    test('"tomar Aurora" is unreachable without a motín or Ramiro on the team', () {
      final choice = endingChoice('Tomar Aurora');
      expect(choice.isAvailableTo(bareCharacter()), isFalse);
      expect(
        choice.isAvailableTo(bareCharacter().copyWith(flags: {'team_has_ramiro': true})),
        isTrue,
      );
    });

    test('boarding endings are blocked once Infección reaches 3, replaced by the infection branch', () {
      final infected = bareCharacter().copyWith(meters: {'infection': 3});
      for (final label in ['Subir a Aurora', 'Ceder los lugares', 'línea regional', 'Tomar Aurora']) {
        expect(
          endingChoice(label).isAvailableTo(infected),
          isFalse,
          reason: '"$label" must be blocked once infected',
        );
      }
      expect(endingChoice('Ocultar la mordida').isAvailableTo(infected), isTrue);
      expect(endingChoice('Confesar la mordida').isAvailableTo(infected), isTrue);
    });

    test('"último relevo" is blocked only when both the mutiny and the north access are already resolved', () {
      final choice = endingChoice('último relevo');
      expect(choice.isAvailableTo(bareCharacter()), isTrue); // both flags default false
      final everythingResolved = bareCharacter().copyWith(
        flags: {'mutiny_active': true, 'north_access_secured': true},
      );
      expect(choice.isAvailableTo(everythingResolved), isFalse);
    });

    test('every ending choice at the selector requires confirmation or is a safe default', () {
      final node = _loadWorld().storyGraph!.nodeById('c10_n02_decision_final')
          as FixedAnchorNode;
      final irreversibleLabels = ['Tomar Aurora', 'último relevo', 'Ocultar la mordida'];
      for (final choice in node.choices) {
        final isIrreversible = irreversibleLabels.any(choice.label.contains);
        if (isIrreversible) {
          expect(
            choice.requiresConfirmation,
            isTrue,
            reason: '"${choice.label}" is a one-way ending and must confirm',
          );
        }
      }
    });

    test('the epilogue never shows Abril forgiving without a confession', () {
      final epilogue = _loadWorld().storyGraph!.nodeById('epilogo') as FixedAnchorNode;
      final forgiveBeat = epilogue.conditionalInserts.firstWhere(
        (i) => i.text.contains('tarda ocho meses en decir la palabra perdón'),
      );
      final notConfessed = bareCharacter().copyWith(
        flags: {'team_has_abril': true, 'confessed_to_abril': false},
        relationships: {'abril': 3},
      );
      expect(forgiveBeat.gate.isSatisfiedBy(notConfessed), isFalse);
    });

    test('the epilogue never shows Saúl sacrificed unless saul_sacrificed is set', () {
      final epilogue = _loadWorld().storyGraph!.nodeById('epilogo') as FixedAnchorNode;
      final sacrificeBeat = epilogue.conditionalInserts.firstWhere(
        (i) => i.text.contains('llave atravesada en la palanca'),
      );
      expect(sacrificeBeat.gate.isSatisfiedBy(bareCharacter()), isFalse);
      expect(
        sacrificeBeat.gate.isSatisfiedBy(bareCharacter().copyWith(flags: {'saul_sacrificed': true})),
        isTrue,
      );
    });

    test('every one of the 6 endings + 2 failures is reachable under some legitimate state '
        '(story bible §30.4 "una ruta por cada final")', () {
      // Each state below is the *minimal* combination of flags/meters that
      // satisfies that ending's hard requirement — not a full 85-turn replay
      // (covered instead by the runtime smoke test), but a direct proof that
      // no ending is a dead letter: every gate the selector declares is
      // satisfiable by content already written earlier in the campaign.
      final routes = <String, Character>{
        'Subir a Aurora': bareCharacter().copyWith(
          flags: {'diesel_deal': true},
          meters: {'infection': 0},
        ),
        'Ceder los lugares': bareCharacter().copyWith(
          flags: {'diesel_deal': true},
          meters: {'infection': 0},
        ),
        'línea regional': bareCharacter().copyWith(
          flags: {'silos_pact': true, 'diesel_deal': true},
          meters: {
            'infection': 0,
            'repair_progress': 4,
            'community_trust': 0,
            'humanity_axis': 2,
          },
        ),
        'Tomar Aurora': bareCharacter().copyWith(
          flags: {'team_has_ramiro': true},
          meters: {'infection': 0},
        ),
        'Rechazar el trato': bareCharacter().copyWith(meters: {'infection': 0}),
        'último relevo': bareCharacter().copyWith(meters: {'infection': 0}),
        'Ocultar la mordida': bareCharacter().copyWith(meters: {'infection': 3}),
        'Confesar la mordida': bareCharacter().copyWith(meters: {'infection': 3}),
      };
      for (final entry in routes.entries) {
        expect(
          endingChoice(entry.key).isAvailableTo(entry.value),
          isTrue,
          reason: '"${entry.key}" should be reachable with its documented minimal state',
        );
      }
    });

    test('fail_anden is reachable once the signal never stabilized', () {
      final node = _loadWorld().storyGraph!.nodeById('c10_n02_decision_final')
          as FixedAnchorNode;
      final choice = node.choices.firstWhere((c) => c.targetNodeId == 'fail_anden');
      final unstableSignal = bareCharacter().copyWith(
        flags: {'signal_green_unstable': true},
        meters: {'infection': 0},
      );
      expect(choice.isAvailableTo(unstableSignal), isTrue);
      expect(choice.isAvailableTo(bareCharacter().copyWith(meters: {'infection': 0})), isFalse);
    });

    test('population/passenger/diesel meters never go negative under normal play', () {
      // ApplyStateDeltas clamps `meter` deltas per-declaration and `resource`
      // deltas at 0 unconditionally (lib/core/engine/apply_state_deltas.dart)
      // — this asserts the declared bounds exist for the counters the story
      // bible calls out (§30.5 "nunca población negativa").
      final world = _loadWorld();
      for (final key in ['diesel_liters', 'population_camara', 'passenger_slots']) {
        final definition = world.meterDefinitions[key];
        expect(definition, isNotNull, reason: 'meter "$key" must declare bounds');
        expect(definition!.min, 0, reason: '"$key" must floor at 0');
      }
    });
  });
}
