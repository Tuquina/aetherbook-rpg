import 'package:flutter/material.dart';

import 'adapters/content/asset_world_repository.dart';
import 'adapters/narrator/fake_narrator_adapter.dart';
import 'app/game_controller.dart';
import 'app/game_screen.dart';
import 'app/theme.dart';

void main() {
  // Composition root: this is the ONLY place that knows about concrete
  // adapters. Everything downstream depends on ports (CLAUDE.md §4). Swapping
  // the FakeNarratorAdapter for the Gemini-backed one later happens here.
  final controller = GameController(
    worldRepository: const AssetWorldRepository(),
    narrator: const FakeNarratorAdapter(),
  );

  runApp(AetherbookApp(controller: controller));
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
      home: GameScreen(controller: controller),
    );
  }
}
