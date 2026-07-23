import '../state/character.dart';
import '../world/world.dart';

/// The player's choices during structured character creation (campaign-bible
/// §5). Free-text fields (pronouns, description) live in the UI/session, not
/// in this input, since they don't affect mechanics.
class CreateCharacterInput {
  const CreateCharacterInput({
    required this.name,
    required this.originId,
    this.freeAttributePoint,
    required this.vowId,
    this.personalItem = '',
  });

  final String name;

  /// Which [CharacterOrigin] the player picked.
  final String originId;

  /// The attribute that receives the free `+1` after the origin's base
  /// values are applied (§5.3: "el jugador suma +1 a un atributo, con
  /// máximo inicial 4"). `null` skips this step entirely — for a world whose
  /// origins are complete, fixed builds with no further customization (e.g.
  /// a curated campaign's "perfil de supervivencia", which already sums to
  /// its full point budget across every attribute).
  final String? freeAttributePoint;

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

    final freePoint = input.freeAttributePoint;
    if (freePoint != null &&
        world.attributeKeys.isNotEmpty &&
        !world.attributeKeys.contains(freePoint)) {
      throw ArgumentError.value(
        freePoint,
        'freeAttributePoint',
        'not one of this world\'s declared attributes',
      );
    }

    final attributes = <String, int>{
      for (final key in world.attributeKeys) key: 1,
      ...origin.baseAttributes,
    };

    if (freePoint != null) {
      final beforeFreePoint = attributes[freePoint] ?? 1;
      final afterFreePoint = beforeFreePoint + 1;
      if (afterFreePoint > _initialAttributeCap) {
        throw ArgumentError(
          'raising $freePoint to $afterFreePoint would '
          'exceed the initial cap of $_initialAttributeCap',
        );
      }
      attributes[freePoint] = afterFreePoint;
    }

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
      // Mirrored into `vars` (alongside the dedicated fields below) so
      // curated content can gate on the chosen origin/vow via `VarGate`
      // (e.g. a profile-specific starting item, or an epilogue beat that
      // depends on which memory item was picked) without a bespoke gate
      // type per chargen concept.
      vars: {'origin_id': origin.id, 'vow_id': vow.id},
      originId: origin.id,
      originTagId: origin.tagId,
      vowId: vow.id,
      personalItem: input.personalItem,
    );
  }
}
