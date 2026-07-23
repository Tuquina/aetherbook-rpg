import 'package:aetherbook/core/world/npc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Npc.fromJson', () {
    test('parses every field', () {
      final npc = Npc.fromJson({
        'id': 'lian_suyin',
        'display_name': 'Lian Suyin',
        'age': 31,
        'role': 'Primera aliada',
        'description': 'Calígrafa funeraria',
        'voice_notes': 'Precisa, seca, nunca ceremoniosa',
        'aliases': ['Suyin', 'la calígrafa'],
      });

      expect(npc.id, 'lian_suyin');
      expect(npc.displayName, 'Lian Suyin');
      expect(npc.age, 31);
      expect(npc.role, 'Primera aliada');
      expect(npc.description, 'Calígrafa funeraria');
      expect(npc.voiceNotes, 'Precisa, seca, nunca ceremoniosa');
      expect(npc.aliases, ['Suyin', 'la calígrafa']);
    });

    test('defaults display name to id and optional fields to empty', () {
      final npc = Npc.fromJson({'id': 'huo_zhen'});
      expect(npc.displayName, 'huo_zhen');
      expect(npc.age, isNull);
      expect(npc.role, isEmpty);
      expect(npc.aliases, isEmpty);
    });
  });
}
