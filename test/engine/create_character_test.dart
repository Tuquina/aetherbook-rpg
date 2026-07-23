import 'package:aetherbook/core/engine/create_character.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/character_origin.dart';
import 'package:aetherbook/core/world/meter_definition.dart';
import 'package:aetherbook/core/world/resource_formula.dart';
import 'package:aetherbook/core/world/vow.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

World _lianshuLikeWorld() {
  return World(
    slug: 'xianxia_lianshu',
    name: 'Los nombres que devora el cielo',
    theme: 'xianxia',
    tone: 'íntimo',
    systemPrompt: '',
    imageStyleSuffix: '',
    defaultDifficulty: 12,
    criticalMargin: 8,
    primaryAttribute: 'espiritu',
    attributeKeys: const ['cuerpo', 'agudeza', 'espiritu', 'presencia'],
    resourceFormulas: const {
      'vitality': ResourceFormula(base: 8, perAttribute: {'cuerpo': 2}),
      'qi': ResourceFormula(base: 4, perAttribute: {'espiritu': 2}),
    },
    meterDefinitions: const {
      'karma': MeterDefinition(min: -3, max: 3, initial: 0),
      'ledger_debt': MeterDefinition(min: 0, initial: 0),
      'evidence_count': MeterDefinition(derivedFromFlags: ['evidence_a']),
    },
    origins: const [
      CharacterOrigin(
        id: 'discipulo_expulsado',
        displayName: 'Discípulo expulsado',
        baseAttributes: {'cuerpo': 3, 'espiritu': 2},
        tagId: 'disciplina_de_secta',
      ),
      CharacterOrigin(
        id: 'copista_itinerante',
        displayName: 'Copista itinerante',
        baseAttributes: {'agudeza': 3, 'presencia': 2},
        tagId: 'documentos_y_sellado',
      ),
    ],
    vows: const [
      Vow(id: 'nadie_me_posee', text: 'No volveré a ser propiedad de nadie.'),
      Vow(id: 'saber_por_que', text: 'Sabré por qué me eligieron.'),
    ],
    startingCharacter: const Character(
      name: 'placeholder',
      level: 1,
      exp: 0,
      attributes: {},
      resources: {},
    ),
    seedNarration: '',
    seedChoices: const [],
  );
}

void main() {
  const create = CreateCharacter();

  group('CreateCharacter', () {
    test('seeds every declared attribute at 1, then applies the origin', () {
      final world = _lianshuLikeWorld();
      final character = create(
        world,
        const CreateCharacterInput(
          name: 'Yuan',
          originId: 'discipulo_expulsado',
          freeAttributePoint: 'agudeza',
          vowId: 'nadie_me_posee',
        ),
      );

      expect(character.attribute('cuerpo'), 3); // from origin
      expect(character.attribute('espiritu'), 2); // from origin
      expect(character.attribute('agudeza'), 2); // 1 base + free point
      expect(character.attribute('presencia'), 1); // untouched baseline
    });

    test('allows the free point to reach exactly the initial cap of 4', () {
      final world = _lianshuLikeWorld();
      expect(
        () => create(
          world,
          const CreateCharacterInput(
            name: 'Yuan',
            originId: 'discipulo_expulsado',
            freeAttributePoint: 'cuerpo', // already 3 -> would become 4, OK
            vowId: 'nadie_me_posee',
          ),
        ),
        returnsNormally,
      );
    });

    test('derives resources from the world\'s formulas using final attributes', () {
      final world = _lianshuLikeWorld();
      final character = create(
        world,
        const CreateCharacterInput(
          name: 'Yuan',
          originId: 'discipulo_expulsado',
          freeAttributePoint: 'espiritu', // 2 -> 3
          vowId: 'nadie_me_posee',
        ),
      );
      // vitality = 8 + cuerpo(3)*2 = 14; qi = 4 + espiritu(3)*2 = 10.
      expect(character.resource('vitality'), 14);
      expect(character.resource('qi'), 10);
    });

    test('initializes non-derived meters and omits derived ones', () {
      final world = _lianshuLikeWorld();
      final character = create(
        world,
        const CreateCharacterInput(
          name: 'Yuan',
          originId: 'discipulo_expulsado',
          freeAttributePoint: 'agudeza',
          vowId: 'nadie_me_posee',
        ),
      );
      expect(character.meter('karma'), 0);
      expect(character.meter('ledger_debt'), 0);
      expect(character.meters.containsKey('evidence_count'), isFalse);
    });

    test('mirrors the chosen origin/vow ids into vars for VarGate-based content', () {
      final world = _lianshuLikeWorld();
      final character = create(
        world,
        const CreateCharacterInput(
          name: 'Yuan',
          originId: 'discipulo_expulsado',
          freeAttributePoint: 'agudeza',
          vowId: 'saber_por_que',
        ),
      );
      expect(character.varValue('origin_id'), 'discipulo_expulsado');
      expect(character.varValue('vow_id'), 'saber_por_que');
    });

    test('records the origin, its tag, the vow, and the personal item', () {
      final world = _lianshuLikeWorld();
      final character = create(
        world,
        const CreateCharacterInput(
          name: 'Yuan',
          originId: 'copista_itinerante',
          freeAttributePoint: 'cuerpo',
          vowId: 'saber_por_que',
          personalItem: 'Un pincel con el mango reparado.',
        ),
      );
      expect(character.originId, 'copista_itinerante');
      expect(character.originTagId, 'documentos_y_sellado');
      expect(character.vowId, 'saber_por_que');
      expect(character.personalItem, 'Un pincel con el mango reparado.');
    });

    test('throws for an unknown origin id', () {
      final world = _lianshuLikeWorld();
      expect(
        () => create(
          world,
          const CreateCharacterInput(
            name: 'Yuan',
            originId: 'no_existe',
            freeAttributePoint: 'cuerpo',
            vowId: 'nadie_me_posee',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('throws for an unknown vow id', () {
      final world = _lianshuLikeWorld();
      expect(
        () => create(
          world,
          const CreateCharacterInput(
            name: 'Yuan',
            originId: 'discipulo_expulsado',
            freeAttributePoint: 'cuerpo',
            vowId: 'no_existe',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('throws when the free point exceeds the initial cap of 4', () {
      final world = World(
        slug: 'x',
        name: 'X',
        theme: '',
        tone: '',
        systemPrompt: '',
        imageStyleSuffix: '',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'cuerpo',
        attributeKeys: const ['cuerpo'],
        origins: const [
          CharacterOrigin(
            id: 'fuerte',
            displayName: 'Fuerte',
            baseAttributes: {'cuerpo': 4},
            tagId: 'x',
          ),
        ],
        vows: const [Vow(id: 'v', text: 't')],
        startingCharacter: const Character(
          name: 'placeholder',
          level: 1,
          exp: 0,
          attributes: {},
          resources: {},
        ),
        seedNarration: '',
        seedChoices: const [],
      );

      expect(
        () => create(
          world,
          const CreateCharacterInput(
            name: 'Yuan',
            originId: 'fuerte',
            freeAttributePoint: 'cuerpo', // already 4 -> would become 5
            vowId: 'v',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('a null freeAttributePoint skips the free-point step entirely (fixed-build origins)', () {
      final world = _lianshuLikeWorld();
      final character = create(
        world,
        const CreateCharacterInput(
          name: 'Yuan',
          originId: 'discipulo_expulsado',
          vowId: 'nadie_me_posee',
        ),
      );
      expect(character.attribute('cuerpo'), 3); // from origin, untouched
      expect(character.attribute('espiritu'), 2); // from origin, untouched
      expect(character.attribute('agudeza'), 1); // baseline, no free point applied
      expect(character.attribute('presencia'), 1); // baseline, no free point applied
    });

    test('throws when the free point targets an attribute the world does not declare', () {
      final world = _lianshuLikeWorld();
      expect(
        () => create(
          world,
          const CreateCharacterInput(
            name: 'Yuan',
            originId: 'discipulo_expulsado',
            freeAttributePoint: 'suerte', // not in attributeKeys
            vowId: 'nadie_me_posee',
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
