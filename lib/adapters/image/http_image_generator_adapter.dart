// prefer_initializing_formals is disabled: private fields on a public
// named-argument constructor can't use `this._field` initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../ports/image_generator_port.dart';

/// Talks to the `generate-image` Edge Function over HTTPS (CLAUDE.md §2.4,
/// §4): same broker pattern as [HttpNarratorAdapter] — the client only ever
/// sees this project's own endpoint and publishable key, never touches the
/// image provider directly.
///
/// Unlike [HttpNarratorAdapter], this **never throws** — image generation
/// is explicitly "nice to have" (GDD §6), never part of the core loop, so
/// any failure (network, timeout, non-200, malformed body) just degrades to
/// `null`: no image this turn, nothing for the caller to catch.
class HttpImageGeneratorAdapter implements ImageGeneratorPort {
  HttpImageGeneratorAdapter({
    required Uri endpoint,
    required String publishableKey,
    http.Client? client,
    Duration timeout = const Duration(seconds: 45),
  })  : _endpoint = endpoint,
        _publishableKey = publishableKey,
        _client = client ?? http.Client(),
        _timeout = timeout;

  final Uri _endpoint;
  final String _publishableKey;
  final http.Client _client;

  // Image generation is slower than narrating text, hence the longer
  // default timeout than HttpNarratorAdapter's 30s.
  final Duration _timeout;

  @override
  Future<String?> generateImage(String prompt) async {
    try {
      final response = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'apikey': _publishableKey,
              'Authorization': 'Bearer $_publishableKey',
            },
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final url = json['imageUrl'];
      return url is String ? url : null;
    } catch (_) {
      return null;
    }
  }
}
