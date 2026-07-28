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

  /// A 0..1 general-advancement indicator for this row's session, or `null`
  /// when there isn't one yet ([entry] is `null`) — callers should render no
  /// bar at all in that case, not an empty one (V2 §2b/§4d, Stage V).
  ///
  /// A completed session is always full. Otherwise: a curated, AI-free
  /// world's active session (one with a real, gated story graph — you
  /// confirmed real chapter progress should be exclusive to "Historias
  /// completas") gets a *real* chapter-based ratio, derived from its own
  /// node-id convention (`c<N>_...`) rather than any new authored metadata —
  /// [world.storyGraph]'s node ids already carry the chapter number, and the
  /// session's [SessionLibraryEntry.currentNodeId] carries the same prefix.
  /// Everything else (freeform/hybrid, AI-narrated) falls back to a soft
  /// `turnCount` heuristic against a fixed ceiling — presented as general
  /// advancement, deliberately not framed as "how much is left", since the
  /// engine has no concept of a freeform story's total length.
  double? get progress {
    final entry = this.entry;
    if (entry == null) return null;
    if (entry.status == 'completed') return 1.0;

    final graph = world.storyGraph;
    final nodeId = entry.currentNodeId;
    if (!world.aiRuntimeRequired && graph != null && nodeId != null) {
      final total = _maxChapter(graph.nodes.keys);
      final current = _chapterOf(nodeId);
      if (total != null && total > 0 && current != null) {
        return (current / total).clamp(0.0, 1.0);
      }
    }

    const heuristicCeiling = 30;
    return (entry.turnCount / heuristicCeiling).clamp(0.0, 1.0);
  }
}

final _chapterPrefix = RegExp(r'^c(\d+)_');

int? _chapterOf(String nodeId) {
  final match = _chapterPrefix.firstMatch(nodeId);
  return match == null ? null : int.parse(match.group(1)!);
}

int? _maxChapter(Iterable<String> nodeIds) {
  int? max;
  for (final id in nodeIds) {
    final chapter = _chapterOf(id);
    if (chapter != null && (max == null || chapter > max)) max = chapter;
  }
  return max;
}

/// "hace 2 d" / "hace 3 h" / "hace 5 min" / "ahora mismo" — shared between
/// `MyStoriesScreen`'s cards and the home dashboard's hero/"Sigue leyendo"
/// tiles (`world_select_screen.dart`), which both need the exact same
/// relative-time phrasing against [DateTime.now] and previously computed it
/// separately.
String relativeTimeLabel(DateTime updatedAt) {
  final since = DateTime.now().difference(updatedAt);
  if (since.inMinutes < 1) return 'ahora mismo';
  if (since.inHours < 1) return 'hace ${since.inMinutes} min';
  if (since.inDays < 1) return 'hace ${since.inHours} h';
  return 'hace ${since.inDays} d';
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
