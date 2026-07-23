/// Computes the campaign-bible "etiqueta" bonus (§5.3): a chargen origin
/// grants a character exactly one tag, and a check that's clearly within
/// that tag's specialty gets `+2`. It never stacks with another tag.
///
/// This isn't a separate roll mechanic — it composes with the `modifiers`
/// already accepted by `ResolvePlayerAction` (which itself caps situational
/// modifiers at ±2, matching the campaign bible exactly). Deciding *whether*
/// a given check's relevant tag is `checkTagId` is a content/classifier
/// concern (curated nodes declare it directly; free actions will need a
/// classifier, same spirit as `InferActionAttribute`) — this class only
/// answers "does the character's tag match?".
class TagBonus {
  const TagBonus({this.bonus = 2});

  final int bonus;

  int evaluate({required String? characterTagId, required String? checkTagId}) {
    if (characterTagId == null || checkTagId == null) return 0;
    return characterTagId == checkTagId ? bonus : 0;
  }
}
