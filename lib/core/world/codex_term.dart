/// A word or concept worth remembering in a curated world's Códice glossary
/// (V2 design prototype §1a's "Términos" chip) — purely descriptive lore,
/// never touched by engine mechanics. Revealed to a specific character via
/// [World]-declared `codex_reveals` on the [StoryNode] where it first matters
/// (`core/narrative/story_node.dart`), never proposed by the narrator.
class CodexTerm {
  const CodexTerm({
    required this.id,
    required this.displayName,
    this.description = '',
  });

  final String id;
  final String displayName;
  final String description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        if (description.isNotEmpty) 'description': description,
      };

  factory CodexTerm.fromJson(Map<String, dynamic> json) {
    return CodexTerm(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? json['id'] as String,
      description: json['description'] as String? ?? '',
    );
  }
}
