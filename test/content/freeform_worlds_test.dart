// Loads the real content assets for the 5 "crea tu propia historia" genres
// (CLAUDE.md Fase 2) — not fakes/fixtures — and checks the structural
// invariants every one of them must share: freeform (no story graph), its
// own chargen (origins + vows, same mechanism as xianxia_lianshu.json), and
// the same opening shape (seed narration + 3 starter choices, free text
// always on). Prose/tone quality needs a human read; this only covers what's
// mechanically checkable.
import 'dart:convert';
import 'dart:io';

import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

const _freeformSlugs = ['isekai', 'xianxia', 'superheroes', 'cyberpunk', 'postapoc'];

World _loadWorld(String slug) {
  final raw = File('assets/worlds/$slug.json').readAsStringSync();
  return World.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  group('freeform genre worlds ("crea tu propia historia")', () {
    for (final slug in _freeformSlugs) {
      group(slug, () {
        test('parses without throwing', () {
          expect(() => _loadWorld(slug), returnsNormally);
        });

        test('is genuinely freeform (no story graph)', () {
          expect(_loadWorld(slug).storyGraph, isNull);
        });

        test('always allows free-text actions', () {
          expect(_loadWorld(slug).allowFreeText, isTrue);
        });

        test('lets the player name their own character', () {
          expect(_loadWorld(slug).hasCustomizableName, isTrue);
        });

        test('has its own chargen: at least 2 origins and 1 vow', () {
          final world = _loadWorld(slug);
          expect(world.origins.length, greaterThanOrEqualTo(2));
          expect(world.vows, isNotEmpty);
        });

        test('every origin only sets attributes the world itself declares', () {
          final world = _loadWorld(slug);
          for (final origin in world.origins) {
            for (final attribute in origin.baseAttributes.keys) {
              expect(world.attributeKeys, contains(attribute),
                  reason: '${origin.id} sets "$attribute", not in ${world.attributeKeys}');
            }
          }
        });

        test('primaryAttribute is one of the world\'s declared attributes', () {
          final world = _loadWorld(slug);
          expect(world.attributeKeys, contains(world.primaryAttribute));
        });

        test('opening scene: non-empty seed narration and exactly 3 starter choices', () {
          final world = _loadWorld(slug);
          expect(world.seedNarration, isNotEmpty);
          expect(world.seedChoices.length, 3);
        });

        test('every origin has its own opening scene, distinct from the '
            "others (CLAUDE.md: the intro must match how the character "
            'arrived, not one generic text for every origin)', () {
          final world = _loadWorld(slug);
          final seenNarrations = <String>{};
          for (final origin in world.origins) {
            expect(origin.seedNarration, isNotNull,
                reason: '${origin.id} has no seed_narration of its own');
            expect(origin.seedNarration, isNotEmpty,
                reason: '${origin.id} has an empty seed_narration');
            expect(origin.seedChoices.length, 3,
                reason: '${origin.id} does not offer exactly 3 starter choices');
            expect(seenNarrations.add(origin.seedNarration!), isTrue,
                reason: '${origin.id} reuses another origin\'s seed_narration verbatim');
          }
        });

        test("every origin's seed narration is substantially longer than a "
            'couple of throwaway lines', () {
          final world = _loadWorld(slug);
          for (final origin in world.origins) {
            expect(origin.seedNarration!.length, greaterThan(400),
                reason: '${origin.id}\'s intro reads as too short to be a '
                    'real opening scene');
          }
        });

        test('the personal item, if provided, gets a hook to actually use it', () {
          final world = _loadWorld(slug);
          expect(world.personalItemSeedHook, isNotNull);
          expect(world.personalItemSeedHook, contains('{{personalItem}}'));
        });

        test('system prompt and image style suffix are authored, not left blank', () {
          final world = _loadWorld(slug);
          expect(world.systemPrompt, isNotEmpty);
          expect(world.imageStyleSuffix, isNotEmpty);
        });
      });
    }

    test('postapoc and postapoc_zombie (the curated campaign) never share a theme', () {
      final freeform = _loadWorld('postapoc');
      final curatedRaw =
          File('assets/worlds/curated_zombie_01_ultimo_tren.json').readAsStringSync();
      final curated = World.fromJson(jsonDecode(curatedRaw) as Map<String, dynamic>);
      expect(freeform.theme, isNot(curated.theme));
    });
  });
}
