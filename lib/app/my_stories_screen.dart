import 'package:flutter/material.dart';

import '../core/state/game_session.dart';
import '../core/world/world.dart';
import 'design/breakpoints.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'design/world_theme.dart';
import 'game_controller.dart';
import 'library_rows.dart';
import 'story_module_screen.dart' show Pressable;
import 'story_navigation.dart';
import 'widgets/atmosphere.dart';

enum _Filter { todas, enCurso, sinEmpezar }

/// The unified "Mis historias" list (V2 design prototype §2b/§8a) — every
/// story the account has across all 3 modules, one flat list instead of
/// needing to remember which module a story belongs to. Does **not**
/// replace `StoryModuleScreen`/`CreateStoryScreen` — those are still where
/// "start something new" of a specific type lives; this is purely a
/// cross-module view of what already exists (or could, for a world with no
/// session yet).
class MyStoriesScreen extends StatefulWidget {
  const MyStoriesScreen({super.key, required this.controller, required this.catalogWorlds});

  final GameController controller;

  /// The full world catalog, already loaded by the caller (`WorldSelectScreen`'s
  /// own `_worlds` future) — avoids a second identical load here.
  final List<World> catalogWorlds;

  static Route<void> route({
    required GameController controller,
    required List<World> catalogWorlds,
  }) =>
      MaterialPageRoute(
        builder: (_) => MyStoriesScreen(controller: controller, catalogWorlds: catalogWorlds),
      );

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen> {
  late final Future<List<SessionLibraryEntry>> _library = widget.controller.storyLibrary();
  _Filter _filter = _Filter.todas;

  List<LibraryRow> _filtered(List<LibraryRow> rows) {
    return switch (_filter) {
      _Filter.todas => rows,
      _Filter.enCurso => rows.where((r) => r.entry?.status == 'active').toList(),
      _Filter.sinEmpezar => rows.where((r) => r.entry == null).toList(),
    };
  }

  Future<void> _openRow(LibraryRow row) async {
    final entry = row.entry;
    if (entry == null) {
      await StoryNavigation.open(context, widget.controller, row.world);
    } else {
      await StoryNavigation.resume(context, widget.controller,
          worldSlug: entry.worldSlug, sessionId: entry.sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: FutureBuilder<List<SessionLibraryEntry>>(
            future: _library,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: AetherColors.gold));
              }
              final allRows = buildLibraryRows(
                catalogWorlds: widget.catalogWorlds,
                entries: snapshot.data!,
              );
              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= AetherBreakpoints.tablet;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 900 : 640),
                      child: Padding(
                        padding: const EdgeInsets.all(AetherSpace.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back_rounded,
                                      color: AetherColors.goldSoft),
                                ),
                                const SizedBox(width: AetherSpace.sm),
                                Expanded(
                                  // `Wrap`, not `Row`: on a narrow phone
                                  // "Mis historias" alone can already claim
                                  // the full width, so the tomo count drops
                                  // to its own line instead of overflowing.
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.end,
                                    spacing: AetherSpace.sm,
                                    children: [
                                      Text('Mis historias',
                                          style: AetherType.display.copyWith(fontSize: 22)),
                                      Text('${allRows.length} tomos',
                                          style: AetherType.caption
                                              .copyWith(color: AetherColors.parchmentDim)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AetherSpace.lg),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final filter in _Filter.values) ...[
                                    _FilterChip(
                                      label: _filterLabel(filter),
                                      count: wide ? _countFor(filter, allRows) : null,
                                      selected: filter == _filter,
                                      onTap: () => setState(() => _filter = filter),
                                    ),
                                    const SizedBox(width: AetherSpace.sm),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AetherSpace.lg),
                            Expanded(
                              child: Builder(builder: (context) {
                                final rows = _filtered(allRows);
                                if (rows.isEmpty) {
                                  return Center(
                                    child: Text(
                                      _filter == _Filter.sinEmpezar
                                          ? 'Ya empezaste todos los mundos disponibles.'
                                          : 'Todavía no hay historias acá.',
                                      style:
                                          AetherType.body.copyWith(color: AetherColors.parchmentDim),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                if (wide) {
                                  return GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 340,
                                      mainAxisExtent: 108,
                                      crossAxisSpacing: AetherSpace.sm,
                                      mainAxisSpacing: AetherSpace.sm,
                                    ),
                                    itemCount: rows.length,
                                    itemBuilder: (context, i) => _LibraryCard(
                                      row: rows[i],
                                      onTap: () => _openRow(rows[i]),
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  itemCount: rows.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: AetherSpace.sm),
                                  itemBuilder: (context, i) => _LibraryCard(
                                    row: rows[i],
                                    onTap: () => _openRow(rows[i]),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _filterLabel(_Filter filter) => switch (filter) {
        _Filter.todas => 'Todas',
        _Filter.enCurso => 'En curso',
        _Filter.sinEmpezar => 'Sin empezar',
      };

  int _countFor(_Filter filter, List<LibraryRow> allRows) => switch (filter) {
        _Filter.todas => allRows.length,
        _Filter.enCurso => allRows.where((r) => r.entry?.status == 'active').length,
        _Filter.sinEmpezar => allRows.where((r) => r.entry == null).length,
      };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The category's row count — shown as "Todas · 6" only at/above
  /// [AetherBreakpoints.tablet] (V2 §4d: mobile chips stay label-only, the
  /// mockup never shows counts there); `null` renders the label alone.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final text = count == null ? label : '$label · $count';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm),
        decoration: BoxDecoration(
          color: selected ? AetherColors.gold.withValues(alpha: 0.16) : null,
          border: Border.all(
            color: selected ? AetherColors.gold.withValues(alpha: 0.5) : AetherColors.hairline,
          ),
          borderRadius: AetherRadius.allPill,
        ),
        child: Text(
          text,
          style: AetherType.label.copyWith(
            fontSize: 12,
            color: selected ? AetherColors.goldBright : AetherColors.parchmentFaint,
          ),
        ),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.row, required this.onTap});

  final LibraryRow row;
  final VoidCallback onTap;

  String get _subtitle {
    final entry = row.entry;
    if (entry == null) return 'Sin empezar';
    if (entry.status == 'completed') return '${entry.characterName} · terminada';
    final since = DateTime.now().difference(entry.updatedAt);
    final relative = since.inMinutes < 1
        ? 'ahora mismo'
        : since.inHours < 1
            ? 'hace ${since.inMinutes} min'
            : since.inDays < 1
                ? 'hace ${since.inHours} h'
                : 'hace ${since.inDays} d';
    return '${entry.characterName} · turno ${entry.turnCount} · $relative';
  }

  String get _title {
    final entry = row.entry;
    final title = entry?.title;
    if (title != null && title.trim().isNotEmpty) return title.trim();
    return row.world.name;
  }

  @override
  Widget build(BuildContext context) {
    final accent = WorldTheme.forWorld(row.world).accent;
    final unstarted = row.entry == null;
    final progress = row.progress;
    return Pressable(
      onTap: onTap,
      // A single `Border` can't mix a bright left accent stripe with a
      // dimmer uniform border elsewhere *and* a borderRadius at the same
      // time (Flutter requires uniform border colors whenever a
      // borderRadius is set) — so the stripe is a separate `Container`
      // inside a `ClipRRect`, not part of the outer decoration's border.
      child: (pressed) => ClipRRect(
        borderRadius: AetherRadius.allMd,
        child: AnimatedContainer(
          duration: AetherMotion.fast,
          decoration: BoxDecoration(
            color: pressed ? AetherColors.surfaceRaised : AetherColors.surface,
            border: Border.all(
              color: unstarted ? AetherColors.hairline : accent.withValues(alpha: 0.3),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AetherSpace.md),
                  child: Opacity(
                    opacity: unstarted ? 0.75 : 1,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: AetherRadius.allSm,
                                ),
                                child: Text(row.world.name.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: accent)),
                              ),
                              const SizedBox(height: 6),
                              Text(_title,
                                  style: AetherType.title.copyWith(fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(_subtitle,
                                  style: AetherType.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (progress != null) ...[
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: AetherRadius.allPill,
                                  child: SizedBox(
                                    height: 3,
                                    child: Stack(children: [
                                      Container(color: AetherColors.void_),
                                      FractionallySizedBox(
                                        widthFactor: progress,
                                        child: Container(color: accent),
                                      ),
                                    ]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
