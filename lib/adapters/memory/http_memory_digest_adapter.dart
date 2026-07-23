import 'dart:convert';

// prefer_initializing_formals is disabled: private fields on a public
// named-argument constructor can't use `this._field` initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'package:http/http.dart' as http;

import '../../core/state/game_session.dart';
import '../../ports/memory_digest_port.dart';

/// Thrown when the call to the memory-digest Edge Function fails: network
/// error, timeout, or a non-2xx response.
class MemoryDigestHttpException implements Exception {
  MemoryDigestHttpException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'MemoryDigestHttpException: $message';
}

/// Talks to the memory-digest Edge Function over HTTPS (CLAUDE.md §2.4, §4).
/// Same pattern as [HttpNarratorAdapter]: the client only sees this project's
/// own endpoint and publishable key, never the Groq API key.
class HttpMemoryDigestAdapter implements MemoryDigestPort {
  HttpMemoryDigestAdapter({
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
  Future<String> summarize({
    required List<Turn> turnsToSummarize,
    String? previousDigest,
  }) async {
    final body = jsonEncode({
      'turnsToSummarize': [
        for (final t in turnsToSummarize)
          {'playerAction': t.playerAction, 'narration': t.narration},
      ],
      'previousDigest': previousDigest,
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'apikey': _publishableKey,
              'Authorization': 'Bearer $_publishableKey',
            },
            body: body,
          )
          .timeout(_timeout);
    } catch (e) {
      throw MemoryDigestHttpException('request failed: $e');
    }

    if (response.statusCode != 200) {
      throw MemoryDigestHttpException(
        'Edge Function responded ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final summary = json['summary'];
    if (summary is! String) {
      throw MemoryDigestHttpException(
        'Edge Function response missing "summary" string',
      );
    }
    return summary;
  }
}
