import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'adapters/auth/supabase_auth_adapter.dart';
import 'adapters/content/asset_world_repository.dart';
import 'adapters/memory/http_memory_digest_adapter.dart';
import 'adapters/narrator/http_narrator_adapter.dart';
import 'adapters/persistence/supabase_game_state_adapter.dart';
import 'app/game_controller.dart';
import 'app/splash_screen.dart';
import 'app/theme.dart';
import 'ports/auth_port.dart';
import 'ports/game_state_repository_port.dart';

// Project URL + publishable key (CLAUDE.md §8: this is NOT a secret — it's
// meant to ship in client code, protected by RLS — unlike the Gemini/Groq
// keys, which never leave the Edge Function).
const _supabaseUrl = 'https://hsgdldztcolteyodiscu.supabase.co';
const _supabasePublishableKey = 'sb_publishable_5i-67CN7D7hDUY-w-iT3YQ_uBtaa_Gw';
final _narratorEndpoint = Uri.parse('$_supabaseUrl/functions/v1/narrator');
final _memoryDigestEndpoint = Uri.parse('$_supabaseUrl/functions/v1/memory-digest');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabase = await _tryInitSupabase();

  // Composition root: this is the ONLY place that knows about concrete
  // adapters. Everything downstream depends on ports (CLAUDE.md §4). Both AI
  // ports now hit the real, deployed Edge Functions (Gemini -> Groq fallback
  // for the narrator, Groq for the memory digest) — Fase 1's last quota-side
  // gate. `xianxia_lianshu` ("Los nombres que devora el cielo") is the world
  // that actually depends on this; `curated_zombie_01_ultimo_tren` never
  // calls either port regardless (`ai_runtime_required: false`).
  final controller = GameController(
    worldRepository: const AssetWorldRepository(),
    narrator: HttpNarratorAdapter(
      endpoint: _narratorEndpoint,
      publishableKey: _supabasePublishableKey,
    ),
    persistence: supabase?.persistence,
    memoryDigest: HttpMemoryDigestAdapter(
      endpoint: _memoryDigestEndpoint,
      publishableKey: _supabasePublishableKey,
    ),
  );

  runApp(AetherbookApp(controller: controller, auth: supabase?.auth));
}

/// Initializes Supabase, signs in anonymously (transparently — RLS needs a
/// `user_id` to scope rows to before the player has ever made a choice) and
/// wires up both Supabase-backed ports. Degrades gracefully to in-memory
/// play and no account features (both `null`, same as Fase 0) if anything
/// fails — e.g. anonymous sign-ins not enabled yet on the project — instead
/// of crashing the app at startup.
Future<({GameStateRepositoryPort persistence, AuthPort auth})?> _tryInitSupabase() async {
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
    final client = Supabase.instance.client;
    final auth = SupabaseAuthAdapter(client);
    await auth.ensureSignedIn();
    return (persistence: SupabaseGameStateAdapter(client), auth: auth);
  } catch (e) {
    debugPrint('Persistencia no disponible, se juega solo en memoria: $e');
    return null;
  }
}

class AetherbookApp extends StatelessWidget {
  const AetherbookApp({super.key, required this.controller, this.auth});

  final GameController controller;

  /// `null` when Supabase failed to initialize (in-memory-only degraded
  /// mode) — `SplashScreen` hides the "guardar tu progreso" affordance in
  /// that case, since there's nothing to attach an email to.
  final AuthPort? auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aetherbook',
      debugShowCheckedModeBanner: false,
      theme: AetherTheme.dark,
      home: SplashScreen(controller: controller, auth: auth),
    );
  }
}
