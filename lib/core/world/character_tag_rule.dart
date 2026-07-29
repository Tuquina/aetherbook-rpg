/// A declarative rule turning one of the character's own boolean flags into
/// a visible tag on `CharacterSheetSheet` (V2 design prototype §4c's
/// "MARCA: DEUDA IMPAGA"-style badge) — purely presentational, never touched
/// by engine mechanics. No color field of its own: the tag always renders
/// with the world's `WorldTheme.secondary` (the same token the mockup's own
/// table already labels "alerta"/"peligro"/"aliado" per world), so adding a
/// tag never means authoring a new color too.
class CharacterTagRule {
  const CharacterTagRule({required this.flagKey, required this.label});

  /// Matched against `character.flag(flagKey)` — shown only when `true`.
  final String flagKey;

  final String label;

  Map<String, dynamic> toJson() => {'flag': flagKey, 'label': label};

  factory CharacterTagRule.fromJson(Map<String, dynamic> json) {
    return CharacterTagRule(
      flagKey: json['flag'] as String,
      label: json['label'] as String,
    );
  }
}
