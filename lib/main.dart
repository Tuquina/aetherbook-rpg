import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'adapters/content/asset_world_repository.dart';
import 'adapters/memory/fake_memory_digest_adapter.dart';
import 'adapters/narrator/fake_narrator_adapter.dart';
import 'adapters/persistence/supabase_game_state_adapter.dart';
import 'app/game_controller.dart';
import 'app/splash_screen.dart';
import 'app/theme.dart';
import 'ports/game_state_repository_port.dart';

// Project URL + publishable key (CLAUDE.md §8: this is NOT a secret — it's
// meant to ship in client code, protected by RLS — unlike the Gemini/Groq
// keys, which never leave the Edge Function).
const _supabaseUrl = 'https://hsgdldztcolteyodiscu.supabase.co';
const _supabasePublishableKey = 'sb_publishable_5i-67CN7D7hDUY-w-iT3YQ_uBtaa_Gw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final persistence = await _tryInitPersistence();

  // Composition root: this is the ONLY place that knows about concrete
  // adapters. Everything downstream depends on ports (CLAUDE.md §4). Both AI
  // ports stay on their Fakes for now — zero quota spent while iterating on
  // UI/UX — even though the real Gemini/Groq-backed adapters already exist,
  // are deployed, and are verified working (HttpNarratorAdapter,
  // HttpMemoryDigestAdapter). Swapping them in later happens here.
  final controller = GameController(
    worldRepository: const AssetWorldRepository(),
    narrator: const FakeNarratorAdapter(),
    persistence: persistence,
    memoryDigest: const FakeMemoryDigestAdapter(),
  );

  runApp(AetherbookApp(controller: controller));
}

/// Initializes Supabase and signs in anonymously so RLS has a `user_id` to
/// scope rows to. Degrades gracefully to in-memory play (persistence = null,
/// same as Fase 0) if anything fails — e.g. anonymous sign-ins not enabled
/// yet on the project — instead of crashing the app at startup.
Future<GameStateRepositoryPort?> _tryInitPersistence() async {
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      await client.auth.signInAnonymously();
    }
    return SupabaseGameStateAdapter(client);
  } catch (e) {
    debugPrint('Persistencia no disponible, se juega solo en memoria: $e');
    return null;
  }
}

class AetherbookApp extends StatelessWidget {
  const AetherbookApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aetherbook',
      debugShowCheckedModeBanner: false,
      theme: AetherTheme.dark,
      home: SplashScreen(controller: controller, worldSlug: 'xianxia_lianshu'),
    );
  }
}
