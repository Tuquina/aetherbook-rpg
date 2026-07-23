import 'package:aetherbook/core/world/character_origin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterOrigin.fromJson', () {
    test('parses id, display name, base attributes and tag', () {
      final origin = CharacterOrigin.fromJson({
        'id': 'discipulo_expulsado',
        'display_name': 'Discípulo expulsado',
        'base_attributes': {'cuerpo': 3, 'espiritu': 2},
        'tag_id': 'disciplina_de_secta',
        'narrative_connection': 'Reconoce protocolos del Pabellón.',
      });

      expect(origin.id, 'discipulo_expulsado');
      expect(origin.displayName, 'Discípulo expulsado');
      expect(origin.baseAttributes, {'cuerpo': 3, 'espiritu': 2});
      expect(origin.tagId, 'disciplina_de_secta');
      expect(origin.narrativeConnection, 'Reconoce protocolos del Pabellón.');
    });

    test('defaults display name to id and connection to empty', () {
      final origin = CharacterOrigin.fromJson({
        'id': 'sanador_de_camino',
        'base_attributes': {'espiritu': 3, 'presencia': 2},
        'tag_id': 'medicina_y_meridianos',
      });
      expect(origin.displayName, 'sanador_de_camino');
      expect(origin.narrativeConnection, '');
    });
  });
}
