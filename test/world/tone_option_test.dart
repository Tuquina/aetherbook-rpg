import 'package:aetherbook/core/world/tone_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToneOption.fromJson', () {
    test('parses id, label, blurb and preview', () {
      final tone = ToneOption.fromJson({
        'id': 'epico',
        'label': 'Épico',
        'blurb': 'Grande, mítico',
        'preview': 'El umbral te reclamó como reclama el mar a los ríos.',
      });
      expect(tone.id, 'epico');
      expect(tone.label, 'Épico');
      expect(tone.blurb, 'Grande, mítico');
      expect(tone.previewText, 'El umbral te reclamó como reclama el mar a los ríos.');
    });

    test('blurb and preview default to empty when omitted', () {
      final tone = ToneOption.fromJson({'id': 'intimo', 'label': 'Íntimo'});
      expect(tone.blurb, '');
      expect(tone.previewText, '');
    });
  });
}
