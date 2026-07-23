import '../state/character.dart';

/// Replaces `{{token}}` placeholders in authored copy with values drawn from
/// [character]'s resources/meters/vars and [protagonistName] (curated-content
/// contract §25.7 "interpolación segura"): no expressions, no HTML, no
/// arbitrary keys — only these concrete, pre-approved sources. A token that
/// matches nothing known is left as-is rather than throwing, so a typo'd
/// token surfaces in a content review/test, not by crashing a player's turn.
class InterpolateCopy {
  const InterpolateCopy();

  static final _tokenPattern = RegExp(r'\{\{(\w+)\}\}');

  String call(String text, {required Character character, String? protagonistName}) {
    if (!text.contains('{{')) return text;
    return text.replaceAllMapped(_tokenPattern, (match) {
      final token = match.group(1)!;
      if (token == 'name' && protagonistName != null) return protagonistName;
      if (character.resources.containsKey(token)) {
        return character.resource(token).toString();
      }
      if (character.meters.containsKey(token)) {
        return character.meter(token).toString();
      }
      if (character.vars.containsKey(token)) return character.vars[token]!;
      return match.group(0)!;
    });
  }
}
