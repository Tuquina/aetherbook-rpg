// Regression test for World.toJson() (added for the World Builder, Admin
// Stage 2): a custom world authored in the editor is persisted as
// `World.toJson()` and reloaded via `World.fromJson`, so it must survive that
// round trip — checked as a fixed point (re-encoding an already-normalized
// tree changes nothing) against real, hand-authored worlds covering every
// collection type (origins, vows, tones, ranks, opponents, npcs, techniques,
// items, places, terms, character tags, story graph).

import 'dart:convert';
import 'dart:io';

import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final path in [
    'assets/worlds/xianxia_lianshu.json',
    'assets/worlds/curated_cyberpunk_02_apagon_violeta.json',
    'assets/worlds/isekai.json',
  ]) {
    test('World.fromJson(world.toJson()) round-trips $path', () {
      final raw = File(path).readAsStringSync();
      final worldJson = jsonDecode(raw) as Map<String, dynamic>;

      final original = World.fromJson(worldJson);
      final roundTripped = World.fromJson(original.toJson());

      // Re-encoding twice must be a fixed point.
      expect(roundTripped.toJson(), original.toJson());

      expect(roundTripped.slug, original.slug);
      expect(roundTripped.name, original.name);
      expect(roundTripped.attributeKeys, original.attributeKeys);
      expect(roundTripped.origins.length, original.origins.length);
      expect(roundTripped.vows.length, original.vows.length);
      expect(roundTripped.tones.length, original.tones.length);
      expect(roundTripped.ranks.length, original.ranks.length);
      expect(roundTripped.opponents.length, original.opponents.length);
      expect(roundTripped.npcs.length, original.npcs.length);
      expect(roundTripped.techniques.length, original.techniques.length);
      expect(roundTripped.items.length, original.items.length);
      expect(roundTripped.places.length, original.places.length);
      expect(roundTripped.terms.length, original.terms.length);
      expect(roundTripped.characterTags.length, original.characterTags.length);
      expect(
        roundTripped.storyGraph?.nodes.keys.toSet(),
        original.storyGraph?.nodes.keys.toSet(),
      );
      expect(
        roundTripped.startingCharacter.attributes,
        original.startingCharacter.attributes,
      );
      expect(
        roundTripped.startingCharacter.resources,
        original.startingCharacter.resources,
      );
    });
  }
}
