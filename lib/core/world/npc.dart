/// A recurring named cast member (campaign-bible §4): declarative reference
/// data for the narrator's voice/context and for resolving which NPC a free
/// action refers to (`core/engine/classify_free_action.dart`'s `targetId`).
/// Minor, single-node NPCs (a market forger, an old registrar) don't get an
/// entry here — they carry no relationship and no aliases to resolve.
class Npc {
  const Npc({
    required this.id,
    required this.displayName,
    this.age,
    this.role = '',
    this.description = '',
    this.voiceNotes = '',
    this.aliases = const [],
  });

  final String id;
  final String displayName;
  final int? age;
  final String role;
  final String description;

  /// Short guidance on how this character speaks (tone, habits, what they
  /// never say) — feeds the narrator's voice contract.
  final String voiceNotes;

  /// Alternate ways the player might refer to this NPC in free text (full
  /// name, nickname, role), used by `ClassifyFreeAction` to resolve
  /// `targetId`.
  final List<String> aliases;

  factory Npc.fromJson(Map<String, dynamic> json) {
    return Npc(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? json['id'] as String,
      age: (json['age'] as num?)?.toInt(),
      role: json['role'] as String? ?? '',
      description: json['description'] as String? ?? '',
      voiceNotes: json['voice_notes'] as String? ?? '',
      aliases: json['aliases'] is List
          ? (json['aliases'] as List).whereType<String>().toList(growable: false)
          : const [],
    );
  }
}
