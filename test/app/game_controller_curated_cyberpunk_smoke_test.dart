// Plays the real curated_cyberpunk_02_apagon_violeta.json content (dart:io,
// not a fixture) through the real GameController, mirroring
// game_controller_curated_zombie_smoke_test.dart — this campaign only ever
// had a static content-schema test (test/content/
// curated_cyberpunk_02_apagon_violeta_test.dart, which inspects the parsed
// graph but never resolves a real turn) plus the zombie campaign's own
// runtime smoke test. Nothing had actually played *this* campaign's real
// JSON through the real engine and proven, at runtime, that it never calls
// NarratorPort (V2 Stage 7: re-verifying AI-free curated stories make zero
// network calls after the whole redesign).
import 'dart:convert';
import 'dart:io';

import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/create_character.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter_test/flutter_test.dart';

World _loadRealWorld() {
  final raw =
      File('assets/worlds/curated_cyberpunk_02_apagon_violeta.json').readAsStringSync();
  return World.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class _RealContentWorldRepository implements WorldRepositoryPort {
  _RealContentWorldRepository(this._world);
  final World _world;

  @override
  Future<World> loadWorld(String slug) async => _world;
}

class _ForbiddenNarrator implements NarratorPort {
  const _ForbiddenNarrator();

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    fail('curated_cyberpunk_02_apagon_violeta must never call NarratorPort');
  }
}

/// Taps whichever available choice matches [labelSubstring] (first match) —
/// mirrors how a player picks from `controller.availableStoryChoices`.
Future<void> _pick(GameController controller, String labelSubstring) async {
  final node = controller.currentNode;
  final choices = switch (node) {
    FixedAnchorNode(:final choices) => choices,
    _ => const <StoryChoice>[],
  };
  final available = [
    for (final c in choices)
      if (c.isAvailableTo(controller.character!)) c,
  ];
  final match = available.firstWhere(
    (c) => c.label.contains(labelSubstring),
    orElse: () => throw StateError(
      'no available choice containing "$labelSubstring" at node '
      '${node?.id}; available: ${available.map((c) => c.label).toList()}',
    ),
  );
  await controller.chooseStoryChoice(match);
  expect(controller.error, isNull, reason: 'after picking "$labelSubstring"');
}

void main() {
  final world = _loadRealWorld();

  GameController controllerWith(Dice dice) => GameController(
        worldRepository: _RealContentWorldRepository(world),
        narrator: const _ForbiddenNarrator(),
        dice: dice,
      );

  group('curated_cyberpunk_02_apagon_violeta — runtime smoke test (real content, real engine)',
      () {
    test('chargen with the fixed protagonist and no free point produces the exact '
        'profile', () async {
      final controller = controllerWith(const FixedDice(15));
      await controller.start(
        'curated_cyberpunk_02_apagon_violeta',
        chargenInput: const CreateCharacterInput(
          name: 'Dante Rivas',
          originId: 'piloto_fantasma',
          vowId: 'ficha_orfeo',
        ),
      );

      expect(controller.error, isNull);
      final character = controller.character!;
      expect(character.name, 'Dante Rivas'); // chargen_customizable_name: false
      expect(character.attribute('reflejos'), 4);
      expect(character.attribute('sistemas'), 2);
      expect(character.attribute('calle'), 2);
      expect(character.attribute('presencia'), 1);
      expect(character.varValue('origin_id'), 'piloto_fantasma');
      expect(character.varValue('vow_id'), 'ficha_orfeo');
      expect(controller.currentNode!.id, 'intro_apagon_violeta');
    });

    test('plays the opening chapter end to end without ever calling NarratorPort, '
        'reaching p1_aerotaxi', () async {
      // reflejos(4) + 15 = 19 vs the reflejos check's DC12 below -> success
      // (and clears the critical_margin of 5, but that's still not a
      // failure branch, so it doesn't matter which of the two fires).
      final controller = controllerWith(const FixedDice(15));
      await controller.start(
        'curated_cyberpunk_02_apagon_violeta',
        chargenInput: const CreateCharacterInput(
          name: 'Dante Rivas',
          originId: 'piloto_fantasma',
          vowId: 'ficha_orfeo',
        ),
      );

      await _pick(controller, 'Empezar');
      expect(controller.currentNode!.id, 'p0_perfil');

      await _pick(controller, 'Revisar la pistola compacta y salir');
      expect(controller.currentNode!.id, 'p0_postura');
      expect(controller.character!.resource('ammo'), 3);
      expect(controller.character!.list('inventory'), contains('pistola_compacta'));

      await _pick(controller, 'Por culpa');
      expect(controller.currentNode!.id, 'p1_entrega_rota');
      expect(controller.character!.varValue('reason_left_orfeo'), 'culpa');

      await _pick(controller, 'Cruzar los carriles cerrados');
      expect(controller.currentNode!.id, 'p1_aerotaxi');
      expect(controller.error, isNull);

      // Confirms the curated, AI-free contract end to end: no narrator call
      // happened above (the ForbiddenNarrator would have failed the test),
      // and there's no free-text affordance offered to the player.
      expect(world.allowFreeText, isFalse);
      expect(world.aiRuntimeRequired, isFalse);
    });
  });
}
