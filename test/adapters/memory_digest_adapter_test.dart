import 'dart:convert';

import 'package:aetherbook/adapters/memory/fake_memory_digest_adapter.dart';
import 'package:aetherbook/adapters/memory/http_memory_digest_adapter.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('FakeMemoryDigestAdapter', () {
    const adapter = FakeMemoryDigestAdapter();

    test('summarizes without a previous digest', () async {
      final summary = await adapter.summarize(
        turnsToSummarize: const [
          Turn(index: 0, playerAction: 'Meditar', narration: 'x', tone: ''),
        ],
      );
      expect(summary, contains('1 turno'));
    });

    test('references the previous digest when continuing', () async {
      final summary = await adapter.summarize(
        turnsToSummarize: const [],
        previousDigest: 'El discípulo dejó su aldea.',
      );
      expect(summary, contains('dejó su aldea'));
    });
  });

  group('HttpMemoryDigestAdapter', () {
    final endpoint = Uri.parse('https://example.supabase.co/functions/v1/memory-digest');

    test('parses the summary from a 200 response', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'summary': 'un resumen'}), 200);
      });

      final adapter = HttpMemoryDigestAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      final summary = await adapter.summarize(
        turnsToSummarize: const [
          Turn(index: 0, playerAction: 'Meditar', narration: 'x', tone: ''),
        ],
      );
      expect(summary, 'un resumen');
    });

    test('sends the turns and previous digest in the request body', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'summary': 'ok'}), 200);
      });

      final adapter = HttpMemoryDigestAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      await adapter.summarize(
        turnsToSummarize: const [
          Turn(index: 0, playerAction: 'Meditar', narration: 'sentiste qi', tone: ''),
        ],
        previousDigest: 'diario previo',
      );

      final turns = capturedBody!['turnsToSummarize'] as List;
      expect(turns, hasLength(1));
      expect(turns.first['playerAction'], 'Meditar');
      expect(turns.first['narration'], 'sentiste qi');
      expect(capturedBody!['previousDigest'], 'diario previo');
    });

    test('throws on a non-200 response', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":"boom"}', 502);
      });

      final adapter = HttpMemoryDigestAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      expect(
        () => adapter.summarize(turnsToSummarize: const []),
        throwsA(isA<MemoryDigestHttpException>()),
      );
    });

    test('throws when the response is missing "summary"', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'foo': 'bar'}), 200);
      });

      final adapter = HttpMemoryDigestAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      expect(
        () => adapter.summarize(turnsToSummarize: const []),
        throwsA(isA<MemoryDigestHttpException>()),
      );
    });
  });
}
