import '../core/state/game_session.dart';
import '../core/world/world.dart';

/// One row of a player's story library: either a real session (any status
/// but `abandoned`, which never appears here) or a catalog world the
/// account has never started. Shared by `MyStoriesScreen` (the full list)
/// and `WorldSelectScreen`'s home dashboard ("Sigue leyendo") so both build
/// the same combined view from `GameController.storyLibrary()` instead of
/// two copies of this logic drifting apart.
class LibraryRow {
  const LibraryRow({required this.world, this.entry});

  final World world;

  /// `null` means "sin empezar" — no session exists for [world] yet.
  final SessionLibraryEntry? entry;
}

/// Combines [entries] (from `GameController.storyLibrary()`) with
/// [catalogWorlds] into one list: a [LibraryRow] per non-abandoned session,
/// newest first (the RPC already orders them), followed by a [LibraryRow]
/// for every catalog world that has no session at all.
List<LibraryRow> buildLibraryRows({
  required List<World> catalogWorlds,
  required List<SessionLibraryEntry> entries,
}) {
  final byWorld = <String, World>{for (final w in catalogWorlds) w.slug: w};
  final startedSlugs = <String>{};
  final rows = <LibraryRow>[];
  for (final entry in entries) {
    if (entry.status == 'abandoned') continue;
    final world = byWorld[entry.worldSlug];
    if (world == null) continue; // stale/removed world content, skip rather than crash
    startedSlugs.add(entry.worldSlug);
    rows.add(LibraryRow(world: world, entry: entry));
  }
  for (final world in catalogWorlds) {
    if (!startedSlugs.contains(world.slug)) {
      rows.add(LibraryRow(world: world));
    }
  }
  return rows;
}
