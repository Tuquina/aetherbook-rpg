import 'package:aetherbook/core/world/vow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vow.fromJson', () {
    test('parses id and text', () {
      final vow = Vow.fromJson({
        'id': 'nadie_me_posee',
        'text': 'No volveré a ser propiedad de nadie.',
      });
      expect(vow.id, 'nadie_me_posee');
      expect(vow.text, 'No volveré a ser propiedad de nadie.');
    });
  });
}
