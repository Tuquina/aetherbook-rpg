import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards Golden Rule §5 (CLAUDE.md): the domain in `lib/core` is pure Dart and
/// must not depend on infrastructure. This fails the build if anything under
/// `core/` imports Flutter, dart:io/ui/html, Supabase, or an HTTP client.
void main() {
  test('lib/core is pure Dart — no infra imports', () {
    final coreDir = Directory('lib/core');
    expect(coreDir.existsSync(), isTrue,
        reason: 'expected lib/core to exist');

    final forbidden = <RegExp>[
      RegExp(r'''import\s+['"]package:flutter/'''),
      RegExp(r'''import\s+['"]dart:io['"]'''),
      RegExp(r'''import\s+['"]dart:ui['"]'''),
      RegExp(r'''import\s+['"]dart:html['"]'''),
      RegExp(r'''import\s+['"]package:http/'''),
      RegExp(r'''import\s+['"]package:supabase'''),
    ];

    final violations = <String>[];
    for (final entity in coreDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.hasMatch(source)) {
          violations.add('${entity.path}: matches ${pattern.pattern}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'core/ must stay infra-free:\n${violations.join('\n')}',
    );
  });
}
