/// A place worth remembering in a curated world's Códice glossary (V2 design
/// prototype §1a's "Lugares" chip) — purely descriptive lore for the player
/// to look up, never touched by engine mechanics. Revealed to a specific
/// character via [World]-declared `codex_reveals` on the [StoryNode] where it
/// first matters (`core/narrative/story_node.dart`), never proposed by the
/// narrator.
class CodexPlace {
  const CodexPlace({
    required this.id,
    required this.displayName,
    this.description = '',
  });

  final String id;
  final String displayName;
  final String description;

  factory CodexPlace.fromJson(Map<String, dynamic> json) {
    return CodexPlace(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? json['id'] as String,
      description: json['description'] as String? ?? '',
    );
  }
}
