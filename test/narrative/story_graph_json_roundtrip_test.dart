// Regression test for the toJson methods added to core/narrative/* and
// core/engine/state_delta.dart for the campaign editor (V2 design prototype
// §9a-9j): every draft is persisted as `StoryGraph.toJson()` and reloaded via
// `StoryGraph.fromJson`, so a graph must survive that round trip byte-for-byte
// (as a re-encoded JSON tree, not literal bytes) — including a real,
// hand-authored campaign with every node type, not just synthetic examples.

import 'dart:convert';
import 'dart:io';

import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StoryGraph.fromJson(graph.toJson()) round-trips the real xianxia campaign', () {
    final raw = File('assets/worlds/xianxia_lianshu.json').readAsStringSync();
    final worldJson = jsonDecode(raw) as Map<String, dynamic>;
    final graphJson = (worldJson['graph'] as Map).cast<String, dynamic>();

    final original = StoryGraph.fromJson(graphJson);
    final roundTripped = StoryGraph.fromJson(original.toJson());

    expect(roundTripped.startNodeId, original.startNodeId);
    expect(roundTripped.nodes.keys.toSet(), original.nodes.keys.toSet());
    // Re-encoding twice must be a fixed point: nothing is lost or reshaped
    // on a second pass once the first pass has already normalized the tree.
    expect(roundTripped.toJson(), original.toJson());
    // No dangling references were introduced/dropped by the round trip.
    expect(roundTripped.unknownTargetIds(), original.unknownTargetIds());
  });

  test('round-trips the second curated-but-hybrid-shaped world too', () {
    final raw =
        File('assets/worlds/curated_cyberpunk_02_apagon_violeta.json')
            .readAsStringSync();
    final worldJson = jsonDecode(raw) as Map<String, dynamic>;
    final graphJson = (worldJson['graph'] as Map).cast<String, dynamic>();

    final original = StoryGraph.fromJson(graphJson);
    final roundTripped = StoryGraph.fromJson(original.toJson());

    expect(roundTripped.toJson(), original.toJson());
  });
}
