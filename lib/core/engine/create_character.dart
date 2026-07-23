import '../state/character.dart';
import '../world/world.dart';

/// The player's choices during structured character creation (campaign-bible
/// §5). Free-text fields (pronouns, description) live in the UI/session, not
/// in this input, since they don't affect mechanics.
class CreateCharacterInput {
  const CreateCharacterInput({
    required this.name,
    required this.originId,
    required this.freeAttributePoint,
    required this.vowId,
    this.personalItem = '',
  });

  final String name;

  /// Which [CharacterOrigin] the player picked.
  final String originId;

  /// The attribute that receives the free `+1` after the origin's base
  /// values are applied (§5.3: "el jugador suma +1 a un atributo, con
  /// máximo inicial 4").
  final String freeAttributePoint;

  /// Which [Vow] the player picked.
  final String vowId;

  /// Free-text description of the personal object (§5.1). Never grants an
  /// automatic bonus.
  final String personalItem;
}

/// Builds a fully-formed starting [Character] from a world's chargen data
/// (campaign-bible §5): every declared attribute starts at `1`, the chosen
/// origin overrides some of them and grants a tag, one free point raises an
/// attribute (capped at the initial max of `4`), and resources/meters are
/// derived the same way as any other starting character (world formulas and
/// definitions — CLAUDE.md §2.2: mechanics live in code, not the prompt).
class CreateCharacter {
  const CreateCharacter();

  static const int _initialAttributeCap = 4;

  Character call(World world, CreateCharacterInput input) {
    final origin = world.originById(input.originId);
    final vow = world.vowById(input.vowId);

    if (world.attributeKeys.isNotEmpty &&
        !world.attributeKeys.contains(input.freeAttributePoint)) {
      throw ArgumentError.value(
        input.freeAttributePoint,
        'freeAttributePoint',
        'not one of this world\'s declared attributes',
      );
    }

    final attributes = <String, int>{
      for (final key in world.attributeKeys) key: 1,
      ...origin.baseAttributes,
    };

    final beforeFreePoint = attributes[input.freeAttributePoint] ?? 1;
    final afterFreePoint = beforeFreePoint + 1;
    if (afterFreePoint > _initialAttributeCap) {
      throw ArgumentError(
        'raising ${input.freeAttributePoint} to $afterFreePoint would '
        'exceed the initial cap of $_initialAttributeCap',
      );
    }
    attributes[input.freeAttributePoint] = afterFreePoint;

    final resources = {
      for (final entry in world.resourceFormulas.entries)
        entry.key: entry.value.evaluate(attributes),
    };

    final meters = {
      for (final entry in world.meterDefinitions.entries)
        if (!entry.value.isDerived) entry.key: entry.value.initial,
    };

    return Character(
      name: input.name,
      level: 1,
      exp: 0,
      attributes: attributes,
      resources: resources,
      meters: meters,
      originId: origin.id,
      originTagId: origin.tagId,
      vowId: vow.id,
      personalItem: input.personalItem,
    );
  }
}
