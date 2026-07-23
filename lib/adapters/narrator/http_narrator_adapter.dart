// prefer_initializing_formals is disabled: these are private fields on a
// public named-argument constructor, and Dart forbids private named params,
// so `this._field` initializing formals aren't usable here.
// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/engine/action_resolution.dart';
import '../../core/state/character.dart';
import '../../core/world/world.dart';
import '../../ports/narrator_port.dart';
import 'narrator_json_parser.dart';

/// Thrown when the call to the narrator Edge Function itself fails: network
/// error, timeout, or a non-2xx response. Distinct from [NarratorParseException],
/// which is about the narrator's *content* being malformed.
class NarratorHttpException implements Exception {
  NarratorHttpException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'NarratorHttpException: $message';
}

/// Talks to the narrator Edge Function over HTTPS (CLAUDE.md §2.4, §4): the
/// client only ever sees this project's own Supabase endpoint and its
/// publishable key, never a Gemini/Groq API key. Swapping providers behind
/// the Edge Function (Gemini -> Groq -> whatever comes next) never touches
/// this class — it depends on [NarratorPort], not on any specific provider.
class HttpNarratorAdapter implements NarratorPort {
  HttpNarratorAdapter({
    required Uri endpoint,
    required String publishableKey,
    http.Client? client,
    Duration timeout = const Duration(seconds: 30),
  })  : _endpoint = endpoint,
        _publishableKey = publishableKey,
        _client = client ?? http.Client(),
        _timeout = timeout;

  final Uri _endpoint;
  final String _publishableKey;
  final http.Client _client;
  final Duration _timeout;

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              // Supabase Edge Functions require this even with verify_jwt +
              // no end-user auth (Fase 0 has none, CLAUDE.md §11) — it's the
              // project's own publishable key, not a user credential.
              'apikey': _publishableKey,
              'Authorization': 'Bearer $_publishableKey',
            },
            body: jsonEncode(_requestBody(request)),
          )
          .timeout(_timeout);
    } catch (e) {
      throw NarratorHttpException('request failed: $e');
    }

    if (response.statusCode != 200) {
      throw NarratorHttpException(
        'Edge Function responded ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return parseNarratorJson(response.body);
  }

  Map<String, Object?> _requestBody(NarratorRequest request) {
    return {
      'world': _worldJson(request.world),
      'character': _characterJson(request.character),
      'playerAction': request.playerAction,
      'resolution': _resolutionJson(request.resolution),
      'recentTurns': request.recentTurns,
    };
  }

  Map<String, Object?> _worldJson(World world) => {
        'slug': world.slug,
        'name': world.name,
        'tone': world.tone,
        'systemPrompt': world.systemPrompt,
        'imageStyleSuffix': world.imageStyleSuffix,
      };

  Map<String, Object?> _characterJson(Character character) => {
        'name': character.name,
        'level': character.level,
        'exp': character.exp,
        'attributes': character.attributes,
        'resources': character.resources,
        'flags': character.flags,
      };

  Map<String, Object?>? _resolutionJson(ActionResolution? resolution) {
    if (resolution == null) return null;
    return {
      'outcome': resolution.outcome.name,
      'attribute': resolution.attribute,
      'modifiers': resolution.modifiers,
      'roll': resolution.roll,
      'difficulty': resolution.difficulty,
      'total': resolution.total,
      'isNatural20': resolution.isNatural20,
      'isNatural1': resolution.isNatural1,
    };
  }
}
