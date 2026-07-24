import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter_test/flutter_test.dart';

const _character = Character(
  name: 'Discípulo',
  level: 1,
  exp: 0,
  attributes: {'cuerpo': 3, 'mente': 5, 'espiritu': 7},
  resources: {},
);

const _world = World(
  slug: 'xianxia',
  name: 'El Sendero del Qi',
  theme: 'xianxia',
  tone: 'épico',
  systemPrompt: '',
  imageStyleSuffix: '',
  defaultDifficulty: 12,
  criticalMargin: 5,
  primaryAttribute: 'espiritu',
  attributeKeywords: {
    'cuerpo': ['forzar', 'escalar'],
    'mente': ['leer', 'descifrar'],
    'espiritu': ['meditar', 'sentir'],
  },
  startingCharacter: _character,
  seedNarration: 'Comienza el sendero.',
  seedChoices: ['Meditar'],
);

class _FakeWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => _world;
}

void main() {
  group('GameController infers the attribute from the action text', () {
    test('a "cuerpo" action resolves against the cuerpo attribute', () async {
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        dice: const FixedDice(1),
      );
      await controller.start('xianxia');

      await controller.choose('Intento forzar la puerta de piedra');

      expect(controller.lastResolution!.attributeKey, 'cuerpo');
      expect(controller.lastResolution!.attribute, 3);
    });

    test('a "mente" action resolves against the mente attribute', () async {
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        dice: const FixedDice(1),
      );
      await controller.start('xianxia');

      await controller.choose('Leer el manuscrito para descifrar su secreto');

      expect(controller.lastResolution!.attributeKey, 'mente');
      expect(controller.lastResolution!.attribute, 5);
    });

    test('an action with no matching keyword falls back to primaryAttribute', () async {
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        dice: const FixedDice(1),
      );
      await controller.start('xianxia');

      await controller.choose('Saludar cordialmente');

      expect(controller.lastResolution!.attributeKey, 'espiritu');
      expect(controller.lastResolution!.attribute, 7);
    });

    test('a predefined suggested choice is inferred the same way as free text', () async {
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        dice: const FixedDice(1),
      );
      await controller.start('xianxia');

      // Seed choice text, tapped as a button rather than typed freely.
      await controller.choose('Meditar');

      expect(controller.lastResolution!.attributeKey, 'espiritu');
    });
  });

  group('GameController refuses a self-granting free action (ClassifyFreeAction §18.7)', () {
    test('rejects the action, sets an error, and never resolves a turn', () async {
      final controller = GameController(
        worldRepository: _SelfGrantWorldRepository(),
        narrator: const _ForbiddenNarratorForSelfGrantTest(),
        dice: const FixedDice(1),
      );
      await controller.start('xianxia');

      await controller.choose('Me convierto en el Gran Maestro del Pico');

      expect(controller.error, isNotNull);
      expect(controller.lastResolution, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('a normal action in the same world still resolves normally', () async {
      final controller = GameController(
        worldRepository: _SelfGrantWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        dice: const FixedDice(1),
      );
      await controller.start('xianxia');

      await controller.choose('Intento meditar junto al altar');

      expect(controller.error, isNull);
      expect(controller.lastResolution!.attributeKey, 'espiritu');
    });
  });
}

class _SelfGrantWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => const World(
        slug: 'xianxia',
        name: 'El Sendero del Qi',
        theme: 'xianxia',
        tone: 'épico',
        systemPrompt: '',
        imageStyleSuffix: '',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'espiritu',
        attributeKeywords: {
          'espiritu': ['meditar', 'sentir'],
        },
        selfGrantPatterns: ['me convierto en', 'obtengo el rango de'],
        startingCharacter: _character,
        seedNarration: 'Comienza el sendero.',
        seedChoices: ['Meditar'],
      );
}

/// Fails the test if reached — proves the self-grant rejection short-circuits
/// `choose()` before the narrator (or the dice, via `lastResolution`) is ever
/// touched.
class _ForbiddenNarratorForSelfGrantTest implements NarratorPort {
  const _ForbiddenNarratorForSelfGrantTest();

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    fail('a rejected self-grant action must never reach the narrator');
  }
}
