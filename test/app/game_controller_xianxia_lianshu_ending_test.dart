// Plays the real xianxia_lianshu.json content (dart:io, not a fixture)
// through the real GameController, past where vertical_slice_test.dart
// stops (c1_n03), all the way to a real ending and the epilogue — proving
// the climax mechanism (`GameController.availableEndings`/`chooseEnding`,
// wired up alongside this test) actually completes the campaign end to end,
// not just that individual nodes parse.
//
// Takes the shortest real route to an ending: from c3_n01_ciudad_que_olvida,
// "Abandonar la disputa e intentar huir" -> x_fuga_confirmacion -> "Confirmar:
// huir del valle" sets fled_valley_confirmed, which is the *only* ending
// (fugitivo_degradado) whose hard requirement allows it — every other ending
// explicitly requires fled_valley_confirmed == false. That makes this path
// deterministic to assert on without simulating the rest of the graph.
import 'dart:convert';
import 'dart:io';

import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/create_character.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter_test/flutter_test.dart';

World _loadWorld() {
  final raw = File('assets/worlds/xianxia_lianshu.json').readAsStringSync();
  return World.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class _RealContentWorldRepository implements WorldRepositoryPort {
  _RealContentWorldRepository(this._world);
  final World _world;

  @override
  Future<World> loadWorld(String slug) async => _world;
}

/// Picks a `StoryChoice` by label — same source `GameScreen` itself reads
/// (`GameController.availableStoryChoices`, gate-filtered, covering every
/// node type including a `StateHubNode`'s exits).
Future<void> _pick(GameController controller, String labelSubstring) async {
  final available = controller.availableStoryChoices;
  final match = available.firstWhere(
    (c) => c.label.contains(labelSubstring),
    orElse: () => throw StateError(
      'no available choice containing "$labelSubstring" at node '
      '${controller.currentNode?.id}; available: ${available.map((c) => c.label).toList()}',
    ),
  );
  await controller.chooseStoryChoice(match);
  expect(controller.error, isNull, reason: 'after picking "$labelSubstring"');
}

void main() {
  final world = _loadWorld();

  test('reaches fugitivo_degradado and the epilogue from a fresh chargen, '
      'entirely through the real engine', () async {
    final controller = GameController(
      worldRepository: _RealContentWorldRepository(world),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      // Natural 20 -> always a critical success, regardless of attribute or
      // difficulty (campaign-bible §6.4/§16.1), so this route needs no
      // per-check bookkeeping.
      dice: const FixedDice(20),
    );

    await controller.start(
      'xianxia_lianshu',
      chargenInput: const CreateCharacterInput(
        name: 'Protagonista de prueba',
        originId: 'discipulo_expulsado',
        freeAttributePoint: 'presencia',
        vowId: 'nadie_me_posee',
      ),
    );

    await _pick(controller, 'Empujar la tapa antes de que la barca llegue a la compuerta');
    await _pick(controller, 'Primero quiero recuperar mi nombre.');
    await _pick(controller, 'Ir a la Torre de las Campanas');
    await _pick(controller, 'Deducir la contraseña del antiguo registrador');
    expect(controller.currentNode!.id, 'c1_n03_coro_en_el_campanario');

    // Extended conflict: 2 successes needed before it lets the scene move on.
    await _pick(controller, 'Contener su forma');
    expect(controller.currentNode!.id, 'c1_n03_coro_en_el_campanario');
    await _pick(controller, 'Escuchar las voces');
    expect(controller.currentNode!.id, 'c2_n01_entrada_al_pabellon');

    await _pick(controller, 'Entrar sin acceso, con una distracción de Huo');
    expect(controller.currentNode!.id, 'c2_n02_salon_quieto');

    await _pick(controller, 'Examinar a los siete');
    expect(controller.currentNode!.id, 'c2_n03_archivo_de_la_lluvia');

    await _pick(controller, 'Reconstruir el patrón a mano');
    expect(controller.currentNode!.id, 'c2_n04_la_fuga');

    await _pick(controller, 'Cruzar por el margen del mundo');
    expect(controller.currentNode!.id, 'c3_n01_ciudad_que_olvida');

    await _pick(controller, 'Abandonar la disputa e intentar huir');
    expect(controller.currentNode!.id, 'x_fuga_confirmacion');

    await _pick(controller, 'Confirmar: huir del valle');
    expect(controller.currentNode!.id, 'c5_n03_ritual_final');
    expect(controller.character!.flag('fled_valley_confirmed'), isTrue);

    // Every other ending's hard requirement explicitly excludes
    // fled_valley_confirmed -- this route can only ever offer one.
    final endings = controller.availableEndings;
    expect(endings, hasLength(1));
    expect(endings.single.id, 'fugitivo_degradado');

    await controller.chooseEnding(endings.single);
    expect(controller.error, isNull);

    expect(controller.character!.flag('ending_fugitivo_degradado'), isTrue);
    // yo_me_nombro is the campaign's AlwaysGate catch-all technique rule --
    // none of the other three rules' gates (karma+public_trust, ledger_debt,
    // a relationship >= 3) are met by a character this early in the story.
    expect(controller.character!.varValue('final_technique_id'), 'yo_me_nombro');

    expect(controller.currentNode!.id, 'e_epilogo');
    expect(controller.currentNode, isA<ResolutionNode>());
    expect((controller.currentNode as ResolutionNode).endings, isEmpty);
    expect(controller.availableStoryChoices, isEmpty);
    expect(controller.availableActivities, isEmpty);
    expect(controller.availableEndings, isEmpty);
    // The epilogue's "la_tablilla" movement has a beat gated specifically on
    // this ending, proving the epilogue actually reacts to what happened
    // rather than only ever showing its catch-all beats.
    expect(controller.narration, contains('La tablilla viaja río abajo sin sello y no vuelve.'));
  });
}
