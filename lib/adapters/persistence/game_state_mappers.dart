// Pure mapping between the domain model and Postgres row shapes (GDD §8).
// Kept free of any Supabase import so it can be unit tested without a
// network call — SupabaseGameStateAdapter is the only thing that touches the
// actual client.

import '../../core/engine/action_resolution.dart';
import '../../core/narrative/extended_conflict.dart';
import '../../core/state/character.dart';
import '../../core/state/game_session.dart';

Map<String, Object?> characterToRow(String sessionId, Character character) {
  return {
    'session_id': sessionId,
    'name': character.name,
    'level': character.level,
    'exp': character.exp,
    'attributes': character.attributes,
    'resources': character.resources,
    'flags': character.flags,
    'meters': character.meters,
    'relationships': character.relationships,
    'lists': character.lists,
    'vars': character.vars,
    'origin_id': character.originId,
    'origin_tag_id': character.originTagId,
    'vow_id': character.vowId,
    'personal_item': character.personalItem,
  };
}

Character characterFromRow(Map<String, dynamic> row) {
  return Character(
    name: row['name'] as String,
    level: row['level'] as int,
    exp: row['exp'] as int,
    attributes: _intMap(row['attributes']),
    resources: _intMap(row['resources']),
    flags: _boolMap(row['flags']),
    meters: _intMap(row['meters']),
    relationships: _intMap(row['relationships']),
    lists: _stringListMap(row['lists']),
    vars: _stringMap(row['vars']),
    originId: row['origin_id'] as String?,
    originTagId: row['origin_tag_id'] as String?,
    vowId: row['vow_id'] as String?,
    personalItem: row['personal_item'] as String?,
  );
}

/// The `game_sessions` columns that track graph position — read alongside
/// the session row in `loadLatestSession`, written by `saveGraphPosition`.
Map<String, Object?> graphPositionToRow({
  String? currentNodeId,
  required int corridorTurnsUsed,
  ExtendedConflictProgress? extendedConflictProgress,
}) {
  return {
    'current_node_id': currentNodeId,
    'corridor_turns_used': corridorTurnsUsed,
    'extended_conflict_progress': extendedConflictProgress == null
        ? null
        : {
            'successes': extendedConflictProgress.successes,
            'failures': extendedConflictProgress.failures,
            'last_attribute_key': extendedConflictProgress.lastAttributeKey,
          },
  };
}

ExtendedConflictProgress? extendedConflictProgressFromRow(Object? value) {
  if (value is! Map) return null;
  return ExtendedConflictProgress(
    successes: (value['successes'] as num?)?.toInt() ?? 0,
    failures: (value['failures'] as num?)?.toInt() ?? 0,
    lastAttributeKey: value['last_attribute_key'] as String?,
  );
}

Map<String, Object?> turnToRow({
  required String sessionId,
  required int turnIndex,
  required String playerAction,
  required ActionResolution? resolution,
  required String narration,
  required String tone,
  required List<String> suggestedChoices,
}) {
  return {
    'session_id': sessionId,
    'turn_index': turnIndex,
    'player_action': playerAction,
    'resolved_mechanics': resolutionToJson(resolution),
    'narration': narration,
    'suggested_choices': suggestedChoices,
    // `tone` isn't a turns column (GDD §8) — it's carried in the domain
    // Turn for UI purposes only, not persisted separately.
  };
}

Turn turnFromRow(Map<String, dynamic> row) {
  return Turn(
    index: row['turn_index'] as int,
    playerAction: row['player_action'] as String,
    narration: row['narration'] as String,
    tone: '',
    suggestedChoices: _stringList(row['suggested_choices']),
  );
}

Map<String, Object?>? resolutionToJson(ActionResolution? resolution) {
  if (resolution == null) return null;
  return {
    'outcome': resolution.outcome.name,
    'attributeKey': resolution.attributeKey,
    'attribute': resolution.attribute,
    'modifiers': resolution.modifiers,
    'roll': resolution.roll,
    'difficulty': resolution.difficulty,
    'total': resolution.total,
    'isNatural20': resolution.isNatural20,
    'isNatural1': resolution.isNatural1,
    'rollMode': resolution.rollMode.name,
    'discardedRoll': resolution.discardedRoll,
  };
}

Map<String, int> _intMap(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k as String, (v as num).toInt()));
  }
  return const {};
}

Map<String, bool> _boolMap(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k as String, v as bool));
  }
  return const {};
}

Map<String, String> _stringMap(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k as String, v as String));
  }
  return const {};
}

Map<String, List<String>> _stringListMap(Object? value) {
  if (value is Map) {
    return value.map(
      (k, v) => MapEntry(k as String, _stringList(v)),
    );
  }
  return const {};
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  return const [];
}
