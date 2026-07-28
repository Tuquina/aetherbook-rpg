// Loads the real curated_cyberpunk_02_apagon_violeta.json content asset —
// not a fake/fixture — and checks structural criteria from the story bible
// (brainstorming-worlds/Historia-Completa-02...): no dangling references,
// every reachable outcome carries authored prose (this campaign makes zero
// AI calls), and the campaign-level contract (ai_runtime_required: false,
// free_text_actions: false) actually holds. Grown chapter by chapter as the
// content is authored — `_expectedNodeIds` only lists nodes that exist so
// far, same pattern as curated_zombie_01_ultimo_tren_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/story_graph_test_helpers.dart';

World _loadWorld() {
  final raw = File('assets/worlds/curated_cyberpunk_02_apagon_violeta.json')
      .readAsStringSync();
  return World.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Nodes authored so far (grows as chapters are added). Prólogo + Capítulos
/// I–III.
const _expectedNodeIds = <String>{
  'intro_apagon_violeta',
  'p0_perfil',
  'p0_postura',
  'p1_entrega_rota',
  'p1_aerotaxi',
  'p2_mensaje_orfeo',
  'c1_n01_garage_cero',
  'c1_n02_secuestrar_noa',
  'c1_n02b_noa_capturada',
  'c1_n03_escape_viaducto',
  'c1_n04_pacto_noa',
  'c2_n01_elegir_apoyo',
  'c2_n01b_elegir_ruta',
  'c2_n02_mercado_neon',
  'c2_n03_tuneles_servicio',
  'c2_n04_clinica_espejo',
  'c2_n05_primer_fragmento',
  'c3_n01_club_cobalto',
  'c3_n02_mesa_orfeo',
  'c3_n03_emboscada_cristal',
  'c3_n04_santos_decide',
  'c4_n01_rastro_mila',
  'c4_n02_hotel_ascendente',
  'c4_n03_piso_sin_ventanas',
  'c4_n04_rescate_falso',
  'c4_n05_mensaje_mila',
  'c5_n01_archivo_asterion',
  'c5_n02_infiltracion_vertical',
  'c5_n03_boveda_civica',
  'c5_n04_libro_violeta',
  'c5_n05_copias',
  'c5_n05b_segunda_copia',
  'c6_n01_guerra_colores',
  'c6_n02_alianza',
  'c6_n03_caceria_aerea',
  'c6_n04_traicion',
  'c7_n01_prision_movil',
  'c7_n02_convoy_orfeo',
  'c7_n03_rescate_mila',
  'c7_n04_quien_queda',
  'c7_n05_reunion',
  'c8_n01_preparativos',
  'c8_n01b_segundo_preparativo',
  'c8_n01c_tercer_preparativo',
  'c8_n02_evacuacion_bajocielo',
  'c8_n03_torre_lux',
  'c8_n04_subasta_violeta',
  'c8_n05_amara',
  'c9_n01_apagon_violeta',
  'c9_n02_ciudad_ciega',
  'c9_n03_nucleo_grid',
  'c9_n04_ultima_persecucion',
  'c10_n01_azotea',
  'c10_n02_decision_final',
  'end_ciudad_abierta',
  'end_deuda_pagada',
  'end_nuevo_rey',
  'end_duenos_noche',
  'end_cero_violeta',
  'end_ultimo_conductor',
  'fail_palimpsesto',
  'fail_sin_nombre',
  'epilogo',
};

/// No pending chapter starts anymore — the campaign is fully authored,
/// prólogo through epílogo. Kept as an empty const (rather than deleted) so
/// the dangling-reference test below still documents its intent.
const _pendingChapterStarts = <String>{};

void main() {
  group('curated_cyberpunk_02_apagon_violeta.json — root config', () {
    test('parses without throwing', () {
      expect(_loadWorld, returnsNormally);
    });

    test('declares zero AI runtime and zero free text', () {
      final world = _loadWorld();
      expect(world.aiRuntimeRequired, isFalse);
      expect(world.allowFreeText, isFalse);
    });

    test('critical margin and default difficulty match the design bible §6.2/§6.3', () {
      final world = _loadWorld();
      expect(world.criticalMargin, 5);
      expect(world.defaultDifficulty, 12);
    });

    test('declares the four campaign attributes (§6.1)', () {
      expect(
        _loadWorld().attributeKeys,
        unorderedEquals(['reflejos', 'sistemas', 'calle', 'presencia']),
      );
    });

    test('widens relationship bounds to [-3, 3] with magnitude cap 3', () {
      final world = _loadWorld();
      expect(world.relationshipMin, -3);
      expect(world.relationshipMax, 3);
      expect(world.relationshipMagnitudeCap, 3);
    });

    test('chargen has no free attribute point and relabels the vow step to "Recuerdo"', () {
      final world = _loadWorld();
      expect(world.hasFreeAttributePoint, isFalse);
      expect(world.chargenVowLabel, 'Recuerdo');
    });
  });

  group('curated_cyberpunk_02_apagon_violeta.json — chargen (§5.2/§5.3)', () {
    test('declares the three fixed profiles, each summing to 9 points', () {
      final origins = _loadWorld().origins;
      expect(origins, hasLength(3));
      for (final origin in origins) {
        final sum = origin.baseAttributes.values.fold(0, (a, b) => a + b);
        expect(sum, 9, reason: '${origin.id} should sum to 9 points');
      }
    });

    test('declares the three recuerdos as vows (§5.3)', () {
      expect(_loadWorld().vows, hasLength(3));
      expect(
        _loadWorld().vows.map((v) => v.id),
        containsAll(['ficha_orfeo', 'llave_mila', 'foto_azotea']),
      );
    });

    test('declares the five Street Cred ranks (§7.2)', () {
      final ranks = _loadWorld().ranks;
      expect(ranks, hasLength(5));
      expect(ranks.map((r) => r.id),
          ['mensajero', 'conocido', 'operador', 'nombre_propio', 'leyenda']);
    });
  });

  group('curated_cyberpunk_02_apagon_violeta.json — resource formulas (§6.5/§6.6)', () {
    test('max health = 10 + reflejos', () {
      final world = _loadWorld();
      final character =
          world.startingCharacter.copyWith(attributes: {'reflejos': 4});
      expect(world.maxResource('health', character), 14);
    });

    test('max ram = 6 + sistemas * 2', () {
      final world = _loadWorld();
      final character =
          world.startingCharacter.copyWith(attributes: {'sistemas': 4});
      expect(world.maxResource('ram', character), 14);
    });
  });

  group('curated_cyberpunk_02_apagon_violeta.json — story graph', () {
    test('starts at intro_apagon_violeta', () {
      expect(_loadWorld().storyGraph!.startNodeId, 'intro_apagon_violeta');
    });

    test('every authored node is a FixedAnchorNode (100% curada, sin IA)', () {
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

    test('the three profile-gated equip choices in p0_perfil are mutually exclusive', () {
      final node = _loadWorld().storyGraph!.nodeById('p0_perfil') as FixedAnchorNode;
      expect(node.choices, hasLength(3));
      final gates = node.choices.map((c) => c.gate).toSet();
      expect(gates, hasLength(3), reason: 'each profile choice must have a distinct gate');
    });
  });

  group('curated_cyberpunk_02_apagon_violeta.json — property invariants', () {
    Character bareCharacter() => const Character(
          name: 'Dante',
          level: 1,
          exp: 0,
          attributes: {},
          resources: {},
        );

    FixedAnchorNode selector() =>
        _loadWorld().storyGraph!.nodeById('c10_n02_decision_final')
            as FixedAnchorNode;

    StoryChoice endingChoice(String labelSubstring) =>
        selector().choices.firstWhere((c) => c.label.contains(labelSubstring));

    test('"Entregar las llaves" (nuevo rey) is unreachable without a Vidrio alliance', () {
      final choice = endingChoice('Entregar las llaves');
      expect(choice.isAvailableTo(bareCharacter()), isFalse);
      expect(
        choice.isAvailableTo(bareCharacter().copyWith(
          vars: {'primary_alliance': 'glass'},
          flags: {'copy_glass': true},
        )),
        isTrue,
      );
    });

    test('"Publicar el Libro" (ciudad abierta) requires the Grid under control and a copy ready', () {
      final choice = endingChoice('Publicar el Libro');
      expect(choice.isAvailableTo(bareCharacter()), isFalse);
      expect(
        choice.isAvailableTo(bareCharacter().copyWith(
          flags: {'grid_controlled': true, 'copy_street': true, 'broadcast_ready': true},
        )),
        isTrue,
      );
    });

    test('every choice targeting a main ending requires confirmation', () {
      const mainEndings = {
        'end_ciudad_abierta',
        'end_deuda_pagada',
        'end_nuevo_rey',
        'end_duenos_noche',
        'end_cero_violeta',
        'end_ultimo_conductor',
      };
      for (final choice in selector().choices) {
        if (mainEndings.contains(choice.targetNodeId)) {
          expect(
            choice.requiresConfirmation,
            isTrue,
            reason: '"${choice.label}" leads to a main ending and must confirm',
          );
        }
      }
    });

    test('every one of the 6 endings + 2 failures is reachable under some legitimate state', () {
      // Minimal flag/meter/var combination that satisfies each gate — proof
      // that no ending declared at the selector is a dead letter.
      final routes = <String, Character>{
        'Publicar el Libro': bareCharacter().copyWith(
          flags: {'grid_controlled': true, 'copy_street': true, 'broadcast_ready': true},
        ),
        'Cambiar el Libro': bareCharacter().copyWith(
          flags: {'amara_deal': true},
          meters: {'mila_condition': 1},
        ),
        'Entregar las llaves': bareCharacter().copyWith(
          vars: {'primary_alliance': 'glass'},
          flags: {'copy_glass': true},
        ),
        'Conservar el Grid': bareCharacter().copyWith(
          flags: {'grid_controlled': true, 'grid_key_ready': true},
        ),
        'Destruir el mecanismo': bareCharacter().copyWith(
          flags: {'grid_controlled': true, 'master_access_key': true},
        ),
        'Quedarte a sostener': bareCharacter(),
        'Dejar que el tiempo se agote': bareCharacter(),
        'Aceptar que ya no queda nada': bareCharacter().copyWith(
          meters: {'mila_condition': 0},
        ),
      };
      for (final entry in routes.entries) {
        expect(
          endingChoice(entry.key).isAvailableTo(entry.value),
          isTrue,
          reason: '"${entry.key}" should be reachable with its documented minimal state',
        );
      }
    });

    test('the epilogue never shows Dante dead unless dante_dead is set', () {
      final epilogue = _loadWorld().storyGraph!.nodeById('epilogo') as FixedAnchorNode;
      final deadBeat = epilogue.conditionalInserts.firstWhere(
        (i) => i.text.contains('apagan el piloto automático'),
      );
      expect(deadBeat.gate.isSatisfiedBy(bareCharacter()), isFalse);
      expect(
        deadBeat.gate.isSatisfiedBy(bareCharacter().copyWith(flags: {'dante_dead': true})),
        isTrue,
      );
    });
  });

  group('curated_cyberpunk_02_apagon_violeta.json — inventory', () {
    test('every inventory id a choice can list_add has a matching item description', () {
      final raw = jsonDecode(
        File('assets/worlds/curated_cyberpunk_02_apagon_violeta.json')
            .readAsStringSync(),
      );
      final addedIds = <String>{};
      void walk(Object? node) {
        if (node is Map) {
          if (node['type'] == 'list_add' && node['key'] == 'inventory') {
            addedIds.add(node['value'] as String);
          }
          node.values.forEach(walk);
        } else if (node is List) {
          node.forEach(walk);
        }
      }

      walk(raw);
      expect(addedIds, isNotEmpty,
          reason: 'sanity check: the campaign does grant items');

      final world = _loadWorld();
      final undescribed =
          addedIds.where((id) => world.findItem(id) == null).toList();
      expect(undescribed, isEmpty,
          reason: 'these ids are granted via list_add but have no entry in '
              '"items" — the inventory screen would show a bare id for them');
    });
  });

  group('curated_cyberpunk_02_apagon_violeta.json — Códice glossary (V2 §1a)', () {
    test('declares 5 places and 5 terms', () {
      final world = _loadWorld();
      expect(world.places, hasLength(5));
      expect(world.terms, hasLength(5));
    });

    test('every codex_reveals id across the graph references a declared '
        'place or term', () {
      final world = _loadWorld();
      final placeIds = world.places.map((p) => 'lugar:${p.id}').toSet();
      final termIds = world.terms.map((t) => 'termino:${t.id}').toSet();
      for (final node in world.storyGraph!.nodes.values) {
        for (final id in node.codexReveals) {
          expect(
            placeIds.contains(id) || termIds.contains(id),
            isTrue,
            reason: '"${node.id}" reveals "$id", which no declared place/term matches',
          );
        }
      }
    });

    test('every declared place and term is revealed somewhere in the graph', () {
      final world = _loadWorld();
      final revealed = {
        for (final node in world.storyGraph!.nodes.values) ...node.codexReveals,
      };
      for (final place in world.places) {
        expect(revealed, contains('lugar:${place.id}'),
            reason: '"${place.displayName}" is never revealed by any node');
      }
      for (final term in world.terms) {
        expect(revealed, contains('termino:${term.id}'),
            reason: '"${term.displayName}" is never revealed by any node');
      }
    });
  });
}
