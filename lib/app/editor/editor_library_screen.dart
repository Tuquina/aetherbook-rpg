import 'package:flutter/material.dart';

import '../../core/authoring/admin_emails.dart';
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
import 'world_builder_screen.dart';

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

typedef _LibraryData = ({
  List<CampaignDraftSummary> drafts,
  List<CampaignDraftSummary> official,
  List<World> baseWorlds,
});

class _EditorLibraryScreenState extends State<EditorLibraryScreen> {
  late Future<_LibraryData> _data = _load();
  late final Future<List<World>> _baseWorlds =
      Future.wait(editorBaseWorldSlugs.map(widget.controller.loadWorldInfo));

  bool get _isAdmin => isAdminEmail(widget.controller.auth?.email);

  Future<_LibraryData> _load() async {
    final results = await Future.wait([
      widget.campaignDrafts.listMine(),
      // Admin-only in practice: for a non-admin caller RLS already returns
      // just the already-published official campaigns (a public list), see
      // `CampaignDraftRepositoryPort.listOfficial`'s own doc comment — but
      // there's nothing useful to show a non-admin here, so skip the call.
      _isAdmin ? widget.campaignDrafts.listOfficial() : Future.value(const []),
      _baseWorlds,
    ]);
    return (
      drafts: results[0] as List<CampaignDraftSummary>,
      official: results[1] as List<CampaignDraftSummary>,
      baseWorlds: results[2] as List<World>,
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

  Future<void> _createCommunityDraft() async {
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

  Future<void> _createOfficialDraft(CampaignOfficialModule module) async {
    final world = await WorldBuilderScreen.open(context);
    if (world == null || !mounted) return;
    final draft = await widget.campaignDrafts.createOfficialDraft(
      customWorld: world,
      officialModule: module,
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

  Future<void> _createDraft() async {
    if (!_isAdmin) return _createCommunityDraft();

    final choice = await showModalBottomSheet<_NewCampaignType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewCampaignTypeSheet(),
    );
    if (choice == null) return;
    switch (choice) {
      case _NewCampaignType.community:
        await _createCommunityDraft();
      case _NewCampaignType.complete:
        await _createOfficialDraft(CampaignOfficialModule.complete);
      case _NewCampaignType.hybrid:
        await _createOfficialDraft(CampaignOfficialModule.hybrid);
    }
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
              final official = snapshot.data!.official;
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
                              child: (drafts.isEmpty && official.isEmpty)
                                  ? Center(
                                      child: Text(
                                        'Todavía no escribiste ninguna historia.',
                                        style: AetherType.body
                                            .copyWith(color: AetherColors.parchmentDim),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : ListView(
                                      children: [
                                        if (official.isNotEmpty) ...[
                                          Text('Oficiales (administración)',
                                              style: EditorType.overline),
                                          const SizedBox(height: AetherSpace.sm),
                                          for (final o in official) ...[
                                            _DraftCard(
                                              summary: o,
                                              accent: accentBySlug[o.baseWorldSlug] ??
                                                  AetherColors.gold,
                                              onTap: () => _openDraft(o),
                                            ),
                                            const SizedBox(height: AetherSpace.sm),
                                          ],
                                          const SizedBox(height: AetherSpace.lg),
                                          Text('Tus historias escritas',
                                              style: EditorType.overline),
                                          const SizedBox(height: AetherSpace.sm),
                                        ],
                                        for (final d in drafts) ...[
                                          _DraftCard(
                                            summary: d,
                                            accent: accentBySlug[d.baseWorldSlug] ??
                                                AetherColors.gold,
                                            onTap: () => _openDraft(d),
                                          ),
                                          const SizedBox(height: AetherSpace.sm),
                                        ],
                                      ],
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
              // Title on its own full-width line so it can wrap to 2 lines
              // instead of ellipsizing mid-word next to the status pill
              // ("Los nombres que d…") -- the pill moves down next to the
              // scene count/timestamp instead, same fix as `_ModuleCard`.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.title.isEmpty ? 'Sin título' : summary.title,
                    style: AetherType.title.copyWith(fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${summary.nodeCount} escenas · ${relativeTimeLabel(summary.updatedAt)}',
                          style: AetherType.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AetherSpace.sm),
                      _StatusPill(published: summary.isPublished),
                    ],
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

enum _NewCampaignType { community, complete, hybrid }

/// The admin-only first step of "Nueva historia" (Admin Stage 3, project
/// decision 2026-07-31): a non-admin never sees this — [_createDraft] skips
/// straight to [_NewCampaignSheet]. An admin picks between an ordinary
/// community novel (shows up only in "Explorar") or an official campaign
/// (lands in the real "Historias completas"/"Historias pre-armadas"
/// catalog once published) — either official option opens the World
/// Builder next, never the base-world picker.
class _NewCampaignTypeSheet extends StatelessWidget {
  const _NewCampaignTypeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text('Qué tipo de historia', style: AetherType.display.copyWith(fontSize: 20)),
          const SizedBox(height: AetherSpace.lg),
          _TypeOption(
            title: 'Historia de comunidad',
            subtitle: 'Solo aparece en Explorar, sobre un mundo existente.',
            icon: Icons.groups_rounded,
            onTap: () => Navigator.of(context).pop(_NewCampaignType.community),
          ),
          const SizedBox(height: AetherSpace.sm),
          _TypeOption(
            title: 'Historia completa (oficial)',
            subtitle: 'Sin narrador de IA en partida, con atributos propios.',
            icon: Icons.auto_stories_rounded,
            onTap: () => Navigator.of(context).pop(_NewCampaignType.complete),
          ),
          const SizedBox(height: AetherSpace.sm),
          _TypeOption(
            title: 'Historia híbrida (oficial)',
            subtitle: 'Vestida por IA en vivo, con atributos propios.',
            icon: Icons.route_rounded,
            onTap: () => Navigator.of(context).pop(_NewCampaignType.hybrid),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
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
          border: Border.all(color: AetherColors.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AetherColors.goldSoft),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AetherType.title.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AetherType.caption),
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
