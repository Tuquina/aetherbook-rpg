import 'dart:convert';

import '../../core/engine/state_delta.dart';
import '../../ports/narrator_port.dart';

/// Thrown when the narrator's raw output cannot be parsed into the contract.
class NarratorParseException implements Exception {
  NarratorParseException(this.message, this.rawOutput);

  final String message;
  final String rawOutput;

  @override
  String toString() => 'NarratorParseException: $message';
}

/// Tolerant parser for the narrator's raw output (CLAUDE.md §5): it strips
/// markdown fences and surrounding prose, then decodes the JSON contract into
/// a [NarratorResponse]. Both the real AI adapter (Gemini) and the
/// [FakeNarratorAdapter] go through this, so the parse pipeline is always
/// exercised in tests.
NarratorResponse parseNarratorJson(String raw) {
  final cleaned = _extractJsonObject(raw);

  final Object? decoded;
  try {
    decoded = jsonDecode(cleaned);
  } on FormatException catch (e) {
    throw NarratorParseException('invalid JSON: ${e.message}', raw);
  }

  if (decoded is! Map<String, dynamic>) {
    throw NarratorParseException('expected a JSON object', raw);
  }

  final narration = decoded['narration'];
  if (narration is! String) {
    throw NarratorParseException('missing "narration" string', raw);
  }

  return NarratorResponse(
    narration: narration,
    suggestedChoices: _stringList(decoded['suggested_choices']),
    stateDeltas: _deltas(decoded['state_deltas']),
    imagePrompt: decoded['image_prompt'] is String
        ? decoded['image_prompt'] as String
        : '',
    tone: decoded['tone'] is String ? decoded['tone'] as String : '',
  );
}

/// Removes ```json fences / preamble and grabs the outermost `{...}` object.
String _extractJsonObject(String raw) {
  var text = raw.trim();

  // Drop a leading fence such as ```json or ``` .
  text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
  if (text.endsWith('```')) {
    text = text.substring(0, text.length - 3);
  }

  // If there is leading/trailing prose, keep only the outermost object.
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) {
    text = text.substring(start, end + 1);
  }

  return text.trim();
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  return const [];
}

List<StateDelta> _deltas(Object? value) {
  if (value is! List) return const [];
  final result = <StateDelta>[];
  for (final item in value) {
    if (item is Map<String, dynamic>) {
      final type = item['type'];
      final key = item['key'];
      if (type is String && key is String) {
        result.add(
          StateDelta(
            type: StateDelta.typeFromString(type),
            key: key,
            value: item['value'],
          ),
        );
      }
    }
  }
  return result;
}
