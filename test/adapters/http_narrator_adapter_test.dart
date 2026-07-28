import 'dart:convert';

import 'package:aetherbook/adapters/narrator/http_narrator_adapter.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/tone_option.dart';
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
    '{"narration":"Meditás en calma.",'
    '"suggested_choices":[{"id":"seguir","label":"Seguir"}],'
    '"proposed_state_deltas":[{"type":"exp","key":"exp","value":50,'
    '"operation":"increment","reason":"meditación exitosa"}],'
    '"image_prompt":"un monje","tone":"sereno",'
    '"memory_facts":[],"node_status":"active"}';

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
        attributeKey: 'espiritu',
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
        memoryDigest: 'El discípulo dejó su aldea natal.',
        nodeFixedReveals: const ['Siete personas ya fueron borradas.'],
        nodeForbiddenReveals: const ['El ritual original distribuía recuerdos.'],
        nodeGoal: 'Obtener exactamente un access_token.',
        isFreeform: true,
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
      expect(capturedBody!['memoryDigest'], 'El discípulo dejó su aldea natal.');
      expect(capturedBody!['nodeFixedReveals'], ['Siete personas ya fueron borradas.']);
      expect(capturedBody!['nodeForbiddenReveals'],
          ['El ritual original distribuía recuerdos.']);
      expect(capturedBody!['nodeGoal'], 'Obtener exactamente un access_token.');
      expect(capturedBody!['isFreeform'], true);
    });

    test('defaults isFreeform to false when not specified', () async {
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
        playerAction: 'x',
        resolution: null,
      ));

      expect(capturedBody!['isFreeform'], false);
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

    test('resolves chosenTone against World.tones into {label, blurb} for '
        'the Edge Function', () async {
      final worldWithTones = World(
        slug: 'isekai',
        name: 'Isekai',
        theme: 'isekai',
        tone: 'aventurero',
        systemPrompt: 'Eres el GM.',
        imageStyleSuffix: 'arte',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'ingenio',
        startingCharacter: _character,
        seedNarration: '',
        seedChoices: const [],
        tones: const [
          ToneOption(
              id: 'epico', label: 'Épico', blurb: 'Grande, mítico', previewText: ''),
          ToneOption(
              id: 'acido', label: 'Ácido', blurb: 'Seco, irónico', previewText: ''),
        ],
      );
      final characterWithTone = _character.copyWith(chosenTone: 'acido');

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
        world: worldWithTones,
        character: characterWithTone,
        playerAction: 'x',
        resolution: null,
      ));

      expect(capturedBody!['chosenTone'], {'label': 'Ácido', 'blurb': 'Seco, irónico'});
    });

    test('sends chosenTone as null when the character never picked one, or '
        'the id doesn\'t match anything the world declares', () async {
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

      // _world/_character declare no tones/chosenTone at all.
      await adapter.narrate(NarratorRequest(
        world: _world,
        character: _character,
        playerAction: 'x',
        resolution: null,
      ));
      expect(capturedBody!['chosenTone'], isNull);
    });

    test('sends vowText and avoidedThemes when the request carries them (V2 §6a/§6b)',
        () async {
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
        playerAction: 'x',
        resolution: null,
        vowText: 'No dejo atrás a nadie que me haya dado su nombre.',
        avoidedThemes: const ['Contenido sexual', 'Crueldad animal'],
      ));

      expect(capturedBody!['vowText'], 'No dejo atrás a nadie que me haya dado su nombre.');
      expect(capturedBody!['avoidedThemes'], ['Contenido sexual', 'Crueldad animal']);
    });

    test('defaults vowText to null and avoidedThemes to an empty list', () async {
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
        playerAction: 'x',
        resolution: null,
      ));

      expect(capturedBody!['vowText'], isNull);
      expect(capturedBody!['avoidedThemes'], isEmpty);
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
