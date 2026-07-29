/// A narrative-tone choice offered at chargen (V2 design prototype's
/// interactive mock: a fixed 3-tone set — épico/íntimo/ácido — with a
/// per-world preview line, since the *tones* are shared across worlds but
/// what they sound like isn't). Declarative and per-world: a world that
/// declares no [World.tones] simply skips the tone step entirely (same
/// optional-step pattern as `hasFreeAttributePoint`).
class ToneOption {
  const ToneOption({
    required this.id,
    required this.label,
    required this.blurb,
    required this.previewText,
  });

  /// Stable id shared across every world that declares this tone (e.g.
  /// `'epico'`) — persisted on `Character.chosenTone` and sent to the
  /// narrator, so it must stay consistent across worlds even though
  /// [previewText] doesn't.
  final String id;

  /// Display name shown at chargen (e.g. `'Épico'`).
  final String label;

  /// Short one-line descriptor shown alongside [label] (e.g. `'Grande,
  /// mítico'`).
  final String blurb;

  /// A short sample of this world's opening narration rewritten in this
  /// tone — lets the player feel the difference before picking, instead of
  /// choosing a bare adjective blind.
  final String previewText;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (blurb.isNotEmpty) 'blurb': blurb,
        if (previewText.isNotEmpty) 'preview': previewText,
      };

  factory ToneOption.fromJson(Map<String, dynamic> json) {
    return ToneOption(
      id: json['id'] as String,
      label: json['label'] as String,
      blurb: json['blurb'] as String? ?? '',
      previewText: json['preview'] as String? ?? '',
    );
  }
}
