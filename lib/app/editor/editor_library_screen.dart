import 'package:flutter/material.dart';

import '../../core/authoring/campaign_draft.dart';
import '../../core/world/world.dart';
import '../../ports/campaign_draft_repository_port.dart';
import '../design/breakpoints.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/world_theme.dart';
import '../game_controller.dart';
import '../library_rows.dart' show relativeTimeLabel;
import '../widgets/atmosphere.dart';
import '../widgets/library_thumbnail.dart';
import 'campaign_map_screen.dart';
import 'design/editor_tokens.dart';
import 'editor_base_worlds.dart';

/// "Tus historias escritas" (V2 design prototype §9a's entry point) — every
/// campaign the account has authored, draft or published, mirroring
/// `MyStoriesScreen`'s shape for the analogous "everything I've played"
/// list. Starting a new one asks which base world it's written on, then
/// opens straight into `CampaignMapScreen`.
class EditorLibraryScreen extends StatefulWidget {
  const EditorLibraryScreen({
    super.key,
    required this.controller,
    required this.campaignDrafts,
  });

  final GameController controller;
  final CampaignDraftRepositoryPort campaignDrafts;

  static Route<void> route({
    required GameController controller,
    required CampaignDraftRepositoryPort campaignDrafts,
  }) =>
      MaterialPageRoute(
        builder: (_) => EditorLibraryScreen(
          controller: controller,
          campaignDrafts: campaignDrafts,
        ),
      );

  @override
  State<EditorLibraryScreen> createState() => _EditorLibraryScreenState();
}

typedef _LibraryData = ({List<CampaignDraftSummary> drafts, List<World> baseWorlds});

class _EditorLibraryScreenState extends State<EditorLibraryScreen> {
  late Future<_LibraryData> _data = _load();
  late final Future<List<World>> _baseWorlds =
      Future.wait(editorBaseWorldSlugs.map(widget.controller.loadWorldInfo));

  Future<_LibraryData> _load() async {
    final results = await Future.wait([widget.campaignDrafts.listMine(), _baseWorlds]);
    return (
      drafts: results[0] as List<CampaignDraftSummary>,
      baseWorlds: results[1] as List<World>,
    );
  }

  void _refresh() => setState(() => _data = _load());

  Future<void> _openDraft(CampaignDraftSummary summary) async {
    await Navigator.of(context).push(
      CampaignMapScreen.route(
        controller: widget.controller,
        campaignDrafts: widget.campaignDrafts,
        draftId: summary.id,
      ),
    );
    _refresh();
  }

  Future<void> _createDraft() async {
    final worlds = await _baseWorlds;
    if (!mounted) return;
    final result = await showModalBottomSheet<({String title, String baseWorldSlug})>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NewCampaignSheet(worlds: worlds),
    );
    if (result == null) return;

    final draft = await widget.campaignDrafts.createDraft(
      baseWorldSlug: result.baseWorldSlug,
      title: result.title,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      CampaignMapScreen.route(
        controller: widget.controller,
        campaignDrafts: widget.campaignDrafts,
        draftId: draft.id!,
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: FutureBuilder<_LibraryData>(
            future: _data,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AetherColors.gold),
                );
              }
              final drafts = snapshot.data!.drafts;
              final accentBySlug = {
                for (final w in snapshot.data!.baseWorlds)
                  w.slug: WorldTheme.forWorld(w).accent,
              };
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
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.end,
                                    spacing: AetherSpace.sm,
                                    children: [
                                      Text('Tus historias escritas',
                                          style: AetherType.display.copyWith(fontSize: 22)),
                                      Text('${drafts.length}',
                                          style: AetherType.caption
                                              .copyWith(color: AetherColors.parchmentDim)),
                                    ],
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _createDraft,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AetherColors.goldBright,
                                    foregroundColor: AetherColors.void_,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: AetherRadius.allMd),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text('Nueva historia',
                                      style: EditorType.button
                                          .copyWith(color: AetherColors.void_)),
                                ),
                              ],
                            ),
                            const SizedBox(height: AetherSpace.lg),
                            Expanded(
                              child: drafts.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Todavía no escribiste ninguna historia.',
                                        style: AetherType.body
                                            .copyWith(color: AetherColors.parchmentDim),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: drafts.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: AetherSpace.sm),
                                      itemBuilder: (context, i) => _DraftCard(
                                        summary: drafts[i],
                                        accent: accentBySlug[drafts[i].baseWorldSlug] ??
                                            AetherColors.gold,
                                        onTap: () => _openDraft(drafts[i]),
                                      ),
                                    ),
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
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.summary, required this.accent, required this.onTap});

  final CampaignDraftSummary summary;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Container(
        padding: const EdgeInsets.all(AetherSpace.md),
        decoration: BoxDecoration(
          color: AetherColors.surface,
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            LibraryThumbnail(imageUrl: summary.coverImageUrl, accent: accent, size: 44),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.title.isEmpty ? 'Sin título' : summary.title,
                          style: AetherType.title.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusPill(published: summary.isPublished),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${summary.nodeCount} escenas · ${relativeTimeLabel(summary.updatedAt)}',
                    style: AetherType.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AetherColors.parchmentFaint),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    final color = published ? AetherColors.success : AetherColors.parchmentFaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AetherRadius.allSm,
      ),
      child: Text(
        published ? 'Publicada' : 'Borrador',
        style: EditorType.pill.copyWith(color: color),
      ),
    );
  }
}

class _NewCampaignSheet extends StatefulWidget {
  const _NewCampaignSheet({required this.worlds});

  final List<World> worlds;

  @override
  State<_NewCampaignSheet> createState() => _NewCampaignSheetState();
}

class _NewCampaignSheetState extends State<_NewCampaignSheet> {
  final _titleController = TextEditingController();
  late String _baseWorldSlug = widget.worlds.first.slug;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AetherSpace.xl, AetherSpace.lg, AetherSpace.xl, AetherSpace.xl),
        decoration: const BoxDecoration(
          color: AetherColors.ink,
          borderRadius: BorderRadius.vertical(top: AetherRadius.lg),
          border: Border(top: BorderSide(color: AetherColors.hairlineStrong)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nueva historia', style: AetherType.display.copyWith(fontSize: 20)),
            const SizedBox(height: AetherSpace.lg),
            Text('Cómo se llama', style: EditorType.overline),
            const SizedBox(height: AetherSpace.sm),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(
                  fontFamily: 'Marcellus', fontSize: 18, color: AetherColors.goldBright),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AetherSpace.lg, vertical: AetherSpace.md),
                filled: true,
                fillColor: AetherColors.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: AetherRadius.allMd,
                  borderSide: const BorderSide(color: AetherColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AetherRadius.allMd,
                  borderSide: const BorderSide(color: AetherColors.gold),
                ),
              ),
            ),
            const SizedBox(height: AetherSpace.lg),
            Text('En qué mundo pasa', style: EditorType.overline),
            const SizedBox(height: AetherSpace.sm),
            Wrap(
              spacing: AetherSpace.sm,
              runSpacing: AetherSpace.sm,
              children: [
                for (final world in widget.worlds)
                  _WorldChip(
                    world: world,
                    selected: world.slug == _baseWorldSlug,
                    onTap: () => setState(() => _baseWorldSlug = world.slug),
                  ),
              ],
            ),
            const SizedBox(height: AetherSpace.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _titleController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop((
                          title: _titleController.text.trim(),
                          baseWorldSlug: _baseWorldSlug,
                        )),
                style: FilledButton.styleFrom(
                  backgroundColor: AetherColors.goldBright,
                  foregroundColor: AetherColors.void_,
                  disabledBackgroundColor: AetherColors.surfaceRaised,
                  padding: const EdgeInsets.symmetric(vertical: AetherSpace.md),
                  shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
                ),
                child: Text('Empezar', style: EditorType.button.copyWith(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldChip extends StatelessWidget {
  const _WorldChip({required this.world, required this.selected, required this.onTap});

  final World world;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = WorldTheme.forWorld(world).accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : AetherColors.surface,
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: selected ? accent : AetherColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: AetherSpace.sm),
            Text(world.name,
                style: EditorType.label.copyWith(
                  color: selected ? accent : AetherColors.parchmentDim,
                )),
          ],
        ),
      ),
    );
  }
}
