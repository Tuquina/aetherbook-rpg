import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'adapters/auth/supabase_auth_adapter.dart';
import 'adapters/content/asset_world_repository.dart';
import 'adapters/content/composite_world_repository.dart';
import 'adapters/image/http_image_generator_adapter.dart';
import 'adapters/memory/http_memory_digest_adapter.dart';
import 'adapters/narrator/http_narrator_adapter.dart';
import 'adapters/persistence/supabase_campaign_draft_adapter.dart';
import 'adapters/persistence/supabase_game_state_adapter.dart';
import 'adapters/settings/supabase_settings_adapter.dart';
import 'app/game_controller.dart';
import 'app/splash_screen.dart';
import 'app/theme.dart';
import 'ports/auth_port.dart';
import 'ports/campaign_draft_repository_port.dart';
import 'ports/game_state_repository_port.dart';
import 'ports/settings_port.dart';

// Project URL + publishable key (CLAUDE.md §8: this is NOT a secret — it's
// meant to ship in client code, protected by RLS — unlike the Gemini/Groq
// keys, which never leave the Edge Function).
const _supabaseUrl = 'https://hsgdldztcolteyodiscu.supabase.co';
const _supabasePublishableKey = 'sb_publishable_5i-67CN7D7hDUY-w-iT3YQ_uBtaa_Gw';
final _narratorEndpoint = Uri.parse('$_supabaseUrl/functions/v1/narrator');
final _memoryDigestEndpoint = Uri.parse('$_supabaseUrl/functions/v1/memory-digest');
final _generateImageEndpoint = Uri.parse('$_supabaseUrl/functions/v1/generate-image');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabase = await _tryInitSupabase();

  // Composition root: this is the ONLY place that knows about concrete
  // adapters. Everything downstream depends on ports (CLAUDE.md §4). Both AI
  // ports now hit the real, deployed Edge Functions (Gemini -> Groq fallback
  // for the narrator, Groq for the memory digest) — Fase 1's last quota-side
  // gate. `xianxia_lianshu` ("Los nombres que devora el cielo") is the world
  // that actually depends on this; `curated_zombie_01_ultimo_tren` never
  // calls either port regardless (`ai_runtime_required: false`). The image
  // generator (GDD §6) is "nice to have" by design — HttpImageGeneratorAdapter
  // never throws, so wiring it in can't turn a provider hiccup into a crash.
  //
  // The world repository falls back to an admin-authored official
  // campaign_drafts row (Admin Stage 3) whenever a slug isn't a bundled
  // asset — only wired in when Supabase itself is up, same degradation as
  // every other Supabase-backed feature below.
  final campaignDrafts = supabase?.campaignDrafts;
  final worldRepository = campaignDrafts != null
      ? CompositeWorldRepository(
          assets: const AssetWorldRepository(),
          campaignDrafts: campaignDrafts,
        )
      : const AssetWorldRepository();
  final controller = GameController(
    worldRepository: worldRepository,
    narrator: HttpNarratorAdapter(
      endpoint: _narratorEndpoint,
      publishableKey: _supabasePublishableKey,
    ),
    persistence: supabase?.persistence,
    memoryDigest: HttpMemoryDigestAdapter(
      endpoint: _memoryDigestEndpoint,
      publishableKey: _supabasePublishableKey,
    ),
    imageGenerator: HttpImageGeneratorAdapter(
      endpoint: _generateImageEndpoint,
      publishableKey: _supabasePublishableKey,
    ),
    auth: supabase?.auth,
    settingsPort: supabase?.settings,
    campaignDrafts: campaignDrafts,
  );

  runApp(AetherbookApp(controller: controller, auth: supabase?.auth));
}

/// Initializes Supabase and wires up both Supabase-backed ports. A real
/// account (Google or email+password, via `AuthPort`) is required before any
/// session exists — there's no anonymous bootstrap: `SplashScreen` gates
/// "Comenzar" on `auth.isAnonymous` and routes to `AccountScreen` first.
/// Degrades gracefully to in-memory play with no account features (both
/// `null`, same as Fase 0) if Supabase itself fails to initialize, instead of
/// crashing the app at startup.
Future<
    ({
      GameStateRepositoryPort persistence,
      AuthPort auth,
      SettingsPort settings,
      CampaignDraftRepositoryPort campaignDrafts,
    })?> _tryInitSupabase() async {
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
    final client = Supabase.instance.client;
    return (
      persistence: SupabaseGameStateAdapter(client),
      auth: SupabaseAuthAdapter(client),
      settings: SupabaseSettingsAdapter(client),
      campaignDrafts: SupabaseCampaignDraftAdapter(client),
    );
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
