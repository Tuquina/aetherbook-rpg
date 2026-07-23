import '../core/world/world.dart';

/// Loads declarative world packages (CLAUDE.md §8). The concrete adapter
/// decides where the data comes from — a bundled asset now, the network or a
/// content repository later — without the game caring.
abstract class WorldRepositoryPort {
  Future<World> loadWorld(String slug);
}
