import 'dart:convert';

import 'package:aetherbook/adapters/narrator/http_narrator_adapter.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _character = Character(
  name: 'Discípulo',
  level: 1,
  exp: 0,
  attributes: {'espiritu': 2},
  resources: {'qi': 10},
);

const _world = World(
  slug: 'xianxia',
  name: 'El Sendero del Qi',
  theme: 'xianxia',
  tone: 'épico',
  systemPrompt: 'Sos el GM.',
  imageStyleSuffix: 'arte xianxia',
  defaultDifficulty: 12,
  criticalMargin: 5,
  primaryAttribute: 'espiritu',
  startingCharacter: _character,
  seedNarration: 'Comienza el sendero.',
  seedChoices: ['Meditar'],
);

const _validResponseJson =
    '{"narration":"Meditás en calma.","suggested_choices":["Seguir"],'
    '"state_deltas":[{"type":"exp","key":"exp","value":50}],'
    '"image_prompt":"un monje","tone":"sereno"}';

void main() {
  final endpoint = Uri.parse('https://example.supabase.co/functions/v1/narrator');

  group('HttpNarratorAdapter', () {
    test('parses a 200 response into a NarratorResponse', () async {
      final client = MockClient((request) async {
        return http.Response(_validResponseJson, 200);
      });

      final adapter = HttpNarratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      final result = await adapter.narrate(NarratorRequest(
        world: _world,
        character: _character,
        playerAction: 'meditar',
        resolution: null,
      ));

      expect(result.narration, 'Meditás en calma.');
      expect(result.tone, 'sereno');
    });

    test('sends the expected headers, URL and JSON body shape', () async {
      Uri? capturedUrl;
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;

      final client = MockClient((request) async {
        capturedUrl = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_validResponseJson, 200);
      });

      final adapter = HttpNarratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key-123',
        client: client,
      );

      final resolution = const ActionResolution(
        outcome: ActionOutcome.success,
        attribute: 2,
        modifiers: 0,
        roll: 10,
        difficulty: 12,
        total: 12,
        isNatural20: false,
        isNatural1: false,
      );

      await adapter.narrate(NarratorRequest(
        world: _world,
        character: _character,
        playerAction: 'forzar la puerta',
        resolution: resolution,
        recentTurns: const ['turno anterior'],
      ));

      expect(capturedUrl, endpoint);
      expect(capturedHeaders!['apikey'], 'pub-key-123');
      expect(capturedHeaders!['Authorization'], 'Bearer pub-key-123');
      expect(capturedHeaders!['Content-Type'], contains('application/json'));

      expect(capturedBody!['playerAction'], 'forzar la puerta');
      expect(capturedBody!['world']['slug'], 'xianxia');
      expect(capturedBody!['character']['name'], 'Discípulo');
      expect(capturedBody!['resolution']['outcome'], 'success');
      expect(capturedBody!['resolution']['total'], 12);
      expect(capturedBody!['recentTurns'], ['turno anterior']);
    });

    test('serializes a null resolution as JSON null (opening turn)', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_validResponseJson, 200);
      });

      final adapter = HttpNarratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      await adapter.narrate(NarratorRequest(
        world: _world,
        character: _character,
        playerAction: '',
        resolution: null,
      ));

      expect(capturedBody!['resolution'], isNull);
    });

    test('throws NarratorHttpException on a non-200 response', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":"boom"}', 502);
      });

      final adapter = HttpNarratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      expect(
        () => adapter.narrate(NarratorRequest(
          world: _world,
          character: _character,
          playerAction: 'x',
          resolution: null,
        )),
        throwsA(
          isA<NarratorHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            502,
          ),
        ),
      );
    });

    test('wraps a network failure as NarratorHttpException', () async {
      final client = MockClient((request) async {
        throw http.ClientException('connection refused');
      });

      final adapter = HttpNarratorAdapter(
        endpoint: endpoint,
        publishableKey: 'pub-key',
        client: client,
      );

      expect(
        () => adapter.narrate(NarratorRequest(
          world: _world,
          character: _character,
          playerAction: 'x',
          resolution: null,
        )),
        throwsA(isA<NarratorHttpException>()),
      );
    });
  });
}
