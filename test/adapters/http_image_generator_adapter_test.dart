import 'dart:convert';

import 'package:aetherbook/adapters/image/http_image_generator_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final endpoint = Uri.parse('https://example.supabase.co/functions/v1/generate-image');

  group('HttpImageGeneratorAdapter', () {
    test('returns the imageUrl from a 200 response', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'imageUrl': 'https://cdn.example/x.jpg', 'cached': false}), 200);
      });

      final adapter = HttpImageGeneratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      final result = await adapter.generateImage('un sendero de montaña, arte xianxia');

      expect(result, 'https://cdn.example/x.jpg');
    });

    test('sends the prompt, apikey and Authorization headers', () async {
      Uri? capturedUrl;
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;

      final client = MockClient((request) async {
        capturedUrl = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'imageUrl': 'https://cdn.example/x.jpg'}), 200);
      });

      final adapter = HttpImageGeneratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key-123',
        client: client,
      );

      await adapter.generateImage('una escena cyberpunk bajo la lluvia');

      expect(capturedUrl, endpoint);
      expect(capturedHeaders!['apikey'], 'pub-key-123');
      expect(capturedHeaders!['Authorization'], 'Bearer pub-key-123');
      expect(capturedBody!['prompt'], 'una escena cyberpunk bajo la lluvia');
    });

    test('returns null (never throws) on a non-200 response', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'boom'}), 502);
      });

      final adapter = HttpImageGeneratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      final result = await adapter.generateImage('algo');

      expect(result, isNull);
    });

    test('returns null (never throws) on a network failure', () async {
      final client = MockClient((request) async {
        throw http.ClientException('connection refused');
      });

      final adapter = HttpImageGeneratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      final result = await adapter.generateImage('algo');

      expect(result, isNull);
    });

    test('returns null when the response body is missing imageUrl', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'cached': false}), 200);
      });

      final adapter = HttpImageGeneratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      final result = await adapter.generateImage('algo');

      expect(result, isNull);
    });

    test('returns null on malformed JSON in the response body', () async {
      final client = MockClient((request) async {
        return http.Response('not json', 200);
      });

      final adapter = HttpImageGeneratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      final result = await adapter.generateImage('algo');

      expect(result, isNull);
    });
  });
}
