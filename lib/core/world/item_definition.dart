/// A declarative description of an inventory item id (CLAUDE.md §8: content
/// never hardcoded in the engine). `Character.lists['inventory']` only ever
/// stores bare ids (`state_delta.dart`'s `list_add`/`list_remove`) — this is
/// what turns one of those ids into something a player can actually read:
/// a name, flavor text, and a category used to pick an icon.
///
/// An id with no matching [ItemDefinition] isn't an error — `World.findItem`
/// returns `null` and the UI falls back to showing the raw id, so a world
/// that hasn't described every item yet still renders without crashing.
class ItemDefinition {
  const ItemDefinition({
    required this.id,
    required this.displayName,
    this.description = '',
    this.category = ItemCategory.misc,
  });

  final String id;
  final String displayName;
  final String description;
  final ItemCategory category;

  factory ItemDefinition.fromJson(Map<String, dynamic> json) {
    return ItemDefinition(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? json['id'] as String,
      description: json['description'] as String? ?? '',
      category: ItemCategory.fromWire(json['category'] as String?),
    );
  }
}

/// Broad shape used to pick an icon in the UI — not a mechanical distinction,
/// purely presentational (CLAUDE.md §2: the engine never branches on this).
enum ItemCategory {
  key,
  tool,
  weapon,
  medicine,
  document,
  misc;

  static ItemCategory fromWire(String? raw) {
    for (final value in ItemCategory.values) {
      if (value.name == raw) return value;
    }
    return ItemCategory.misc;
  }
}
