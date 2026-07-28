import 'package:flutter/material.dart';

import '../core/world/world.dart';
import 'chargen_screen.dart';
import 'design/tokens.dart';
import 'game_controller.dart';
import 'game_screen.dart';

/// The "how do we enter a story" decision, in one place — originally private
/// to `WorldSelectScreen`, extracted so `MyStoriesScreen` (V2 §2b/§8a) can
/// resume/open a story exactly the same way instead of a second copy of
/// this logic drifting out of sync.
abstract final class StoryNavigation {
  static void goToGame(BuildContext context, GameController controller, String worldSlug) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        pageBuilder: (_, _, _) => GameScreen(controller: controller, worldSlug: worldSlug),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  static void goToChargen(
    BuildContext context,
    GameController controller,
    World world, {
    bool forceNew = false,
    bool alwaysCreateNew = false,
  }) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        pageBuilder: (_, _, _) => ChargenScreen(
          controller: controller,
          worldSlug: world.slug,
          world: world,
          forceNew: forceNew,
          alwaysCreateNew: alwaysCreateNew,
        ),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  /// Opens [world]: resumes the in-memory session if it's already this one,
  /// otherwise goes to chargen (only when the world declares origins and no
  /// persisted session exists yet) or straight into the game.
  static Future<void> open(
    BuildContext context,
    GameController controller,
    World world,
  ) async {
    if (controller.isReady && controller.world?.slug == world.slug) {
      goToGame(context, controller, world.slug);
      return;
    }
    final needsChargen =
        world.origins.isNotEmpty && !await controller.hasPersistedSession(world.slug);
    if (!context.mounted) return;
    if (needsChargen) {
      goToChargen(context, controller, world);
    } else {
      goToGame(context, controller, world.slug);
    }
  }

  /// Resumes one exact saved session by id — unlike [open], never goes
  /// through chargen (the character already exists) and never guesses "the
  /// latest" (used where more than one session for the same world can exist,
  /// CLAUDE.md Fase 2).
  static Future<void> resume(
    BuildContext context,
    GameController controller, {
    required String worldSlug,
    required String sessionId,
  }) async {
    await controller.start(worldSlug, sessionId: sessionId);
    if (!context.mounted) return;
    if (controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AetherColors.surfaceRaised,
          content: Text(controller.error!,
              style: const TextStyle(color: AetherColors.parchment)),
        ),
      );
      return;
    }
    goToGame(context, controller, worldSlug);
  }
}
