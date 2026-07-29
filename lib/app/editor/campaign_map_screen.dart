import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/authoring/campaign_draft.dart';
import '../../core/authoring/campaign_graph_edits.dart';
import '../../core/narrative/story_choice.dart';
import '../../core/narrative/story_graph.dart';
import '../../core/narrative/story_node.dart';
import '../../core/world/world.dart';
import '../../ports/campaign_draft_repository_port.dart';
import '../design/breakpoints.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/world_theme.dart';
import '../game_controller.dart';
import '../library_rows.dart' show relativeTimeLabel;
import 'choice_editor_screen.dart';
import 'corridor_editor_screen.dart';
import 'cover_editor_screen.dart';
import 'design/editor_tokens.dart';
import 'editor_base_worlds.dart';
import 'ending_editor_screen.dart';
import 'hub_editor_screen.dart';
import 'widgets/chip_list_field.dart';

/// The campaign editor's map — a `StoryGraph` under construction (V2 design
/// prototype §9a desktop / §9d mobile). Desktop gets a node-graph canvas
/// (columns laid out by `CampaignGraphEdits.bfsLayers`, not free-drag
/// positioning — the mockup's own layout is deterministic, not manually
/// arranged); phone/tablet get a flat scene list instead, matching §9d.
///
/// Stage-2 scope: structural graph editing (add/rename/delete a node, wire
/// bare label+target connections between nodes) and a minimal body-text
/// field per node. The full per-type authoring surfaces this screen's node
/// inspector eventually opens — gate/check/outcome-band editing for a
/// choice (§9b/9e), the corridor's guardrail chip-lists (§9g), a hub's
/// activities (§9h), an ending's difficulty ladder (§9c) — are a following
/// stage; until then those sections show a "próximamente" placeholder
/// rather than a broken/half-working form.
class CampaignMapScreen extends StatefulWidget {
  const CampaignMapScreen({
    super.key,
    required this.controller,
    required this.campaignDrafts,
    required this.draftId,
  });

  final GameController controller;
  final CampaignDraftRepositoryPort campaignDrafts;
  final String draftId;

  static Route<void> route({
    required GameController controller,
    required CampaignDraftRepositoryPort campaignDrafts,
    required String draftId,
  }) =>
      MaterialPageRoute(
        builder: (_) => CampaignMapScreen(
          controller: controller,
          campaignDrafts: campaignDrafts,
          draftId: draftId,
        ),
      );

  @override
  State<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends State<CampaignMapScreen> {
  CampaignDraft? _draft;
  World? _baseWorld;
  List<World>? _allBaseWorlds;
  String? _selectedNodeId;
  bool _saving = false;
  int _nextNodeSeq = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.campaignDrafts.loadDraft(widget.draftId),
      Future.wait(editorBaseWorldSlugs.map(widget.controller.loadWorldInfo)),
    ]);
    final draft = results[0] as CampaignDraft?;
    final baseWorlds = results[1] as List<World>;
    if (draft == null || !mounted) return;
    final world = baseWorlds.firstWhere(
      (w) => w.slug == draft.baseWorldSlug,
      orElse: () => baseWorlds.first,
    );
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _baseWorld = world;
      _allBaseWorlds = baseWorlds;
      _nextNodeSeq = draft.graph.nodes.length + 1;
      _selectedNodeId ??= draft.graph.nodes.isEmpty ? null : draft.graph.startNodeId;
    });
  }

  Future<void> _openCover() async {
    final draft = _draft;
    final baseWorlds = _allBaseWorlds;
    if (draft == null || baseWorlds == null) return;
    final updated = await CoverEditorScreen.open(
      context,
      draft: draft,
      campaignDrafts: widget.campaignDrafts,
      baseWorlds: baseWorlds,
      nodeCount: draft.graph.nodes.length,
    );
    if (updated == null) return;
    final newWorld = baseWorlds.firstWhere(
      (w) => w.slug == updated.baseWorldSlug,
      orElse: () => baseWorlds.first,
    );
    setState(() => _baseWorld = newWorld);
    await _save(updated);
  }

  Future<void> _save(CampaignDraft next) async {
    setState(() {
      _draft = next;
      _saving = true;
    });
    await widget.campaignDrafts.saveDraft(next);
    final reloaded = await widget.campaignDrafts.loadDraft(widget.draftId);
    if (!mounted) return;
    setState(() {
      _draft = reloaded ?? next;
      _saving = false;
    });
  }

  String _freshNodeId() {
    var id = 'n${_nextNodeSeq++}';
    while (_draft!.graph.nodes.containsKey(id)) {
      id = 'n${_nextNodeSeq++}';
    }
    return id;
  }

  Future<void> _addNode(NodeKind kind) async {
    final draft = _draft!;
    final id = _freshNodeId();
    final node = CampaignGraphEdits.blankNode(id, kind);
    var graph = CampaignGraphEdits.withNode(draft.graph, node);
    if (graph.startNodeId.isEmpty) {
      graph = CampaignGraphEdits.withStartNode(graph, id);
    }
    setState(() => _selectedNodeId = id);
    await _save(draft.copyWith(graph: graph));
  }

  Future<void> _renameNode(String id, String title) async {
    final draft = _draft!;
    await _save(draft.copyWith(nodeTitles: {...draft.nodeTitles, id: title}));
  }

  Future<void> _deleteNode(String id) async {
    final draft = _draft!;
    final titles = {...draft.nodeTitles}..remove(id);
    // Also drop any choice/exit elsewhere in the graph that targeted this
    // node — otherwise deleting it would silently create a "cabo suelto"
    // the author never asked for (a graph edit, unlike a real dangling
    // reference the checklist should actually flag, is squarely this
    // screen's job to keep consistent).
    var graph = CampaignGraphEdits.withoutNode(draft.graph, id);
    graph = StoryGraph(
      startNodeId: graph.startNodeId,
      nodes: {
        for (final entry in graph.nodes.entries)
          entry.key: _withoutTarget(entry.value, id),
      },
    );
    if (_selectedNodeId == id) _selectedNodeId = null;
    await _save(draft.copyWith(graph: graph, nodeTitles: titles));
  }

  StoryNode _withoutTarget(StoryNode node, String targetId) {
    if (node is ResolutionNode) return node;
    final choices = switch (node) {
      FixedAnchorNode(:final choices) => choices,
      BoundedCorridorNode(:final choices) => choices,
      StateHubNode(:final exits) => exits,
      ResolutionNode() => const <StoryChoice>[],
    };
    var updated = node;
    for (var i = choices.length - 1; i >= 0; i--) {
      if (choices[i].targetNodeId == targetId) {
        updated = CampaignGraphEdits.withRemovedChoiceAt(updated, i);
      }
    }
    return updated;
  }

  Future<void> _setStartNode(String id) async {
    final draft = _draft!;
    await _save(draft.copyWith(graph: CampaignGraphEdits.withStartNode(draft.graph, id)));
  }

  Future<void> _addChoice(String fromNodeId, {required String label, required String targetNodeId}) async {
    final draft = _draft!;
    final node = draft.graph.nodes[fromNodeId]!;
    final choice = CampaignGraphEdits.blankChoice(label: label, targetNodeId: targetNodeId);
    final updatedNode = CampaignGraphEdits.withAddedChoice(node, choice);
    await _save(draft.copyWith(graph: CampaignGraphEdits.withNode(draft.graph, updatedNode)));
  }

  Future<void> _removeChoiceAt(String fromNodeId, int index) async {
    final draft = _draft!;
    final node = draft.graph.nodes[fromNodeId]!;
    final updatedNode = CampaignGraphEdits.withRemovedChoiceAt(node, index);
    await _save(draft.copyWith(graph: CampaignGraphEdits.withNode(draft.graph, updatedNode)));
  }

  Future<void> _setBodyText(String nodeId, String text) async {
    final draft = _draft!;
    final node = draft.graph.nodes[nodeId]!;
    final updatedNode = CampaignGraphEdits.withBodyText(node, text);
    await _save(draft.copyWith(graph: CampaignGraphEdits.withNode(draft.graph, updatedNode)));
  }

  /// Swaps in a whole new [node] for [nodeId], optionally renaming it in the
  /// same save — used by the full node editors (choice/corridor/hub/ending),
  /// which each hand back a complete replacement rather than one field.
  Future<void> _replaceNode(String nodeId, StoryNode node, {String? title}) async {
    final draft = _draft!;
    await _save(draft.copyWith(
      graph: CampaignGraphEdits.withNode(draft.graph, node),
      nodeTitles: title == null ? draft.nodeTitles : {...draft.nodeTitles, nodeId: title},
    ));
  }

  _NodeCallbacks get _callbacks => (
        onRename: _renameNode,
        onDelete: _deleteNode,
        onSetStart: _setStartNode,
        onAddChoice: _addChoice,
        onRemoveChoiceAt: _removeChoiceAt,
        onBodyTextChanged: _setBodyText,
        onComingSoon: _showComingSoon,
        onReplaceNode: _replaceNode,
      );

  void _showComingSoon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AetherColors.surfaceRaised,
        content: Text('$what llega en la próxima etapa del editor.',
            style: const TextStyle(color: AetherColors.parchment)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final world = _baseWorld;
    if (draft == null || world == null) {
      return const Scaffold(
        backgroundColor: AetherColors.void_,
        body: Center(child: CircularProgressIndicator(color: AetherColors.gold)),
      );
    }
    final accent = WorldTheme.forWorld(world).accent;
    final danglingCount = draft.graph.unknownTargetIds().length;

    return Scaffold(
      backgroundColor: AetherColors.void_,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= AetherBreakpoints.desktop;
            return Column(
              children: [
                _Header(
                  title: draft.title.isEmpty ? 'Sin título' : draft.title,
                  worldName: world.name,
                  published: draft.isPublished,
                  danglingCount: danglingCount,
                  saving: _saving,
                  updatedAt: draft.updatedAt,
                  onBack: () => Navigator.of(context).pop(),
                  onCover: _openCover,
                  onPlaytest: () => _showComingSoon('Probar el borrador'),
                  onPublish: () => _showComingSoon('Publicar'),
                ),
                Expanded(
                  child: desktop
                      ? _DesktopBody(
                          draft: draft,
                          accent: accent,
                          selectedNodeId: _selectedNodeId,
                          onSelect: (id) => setState(() => _selectedNodeId = id),
                          onAddNode: _addNode,
                          callbacks: _callbacks,
                          worldAttributeKeys: world.attributeKeys,
                        )
                      : _MobileBody(
                          draft: draft,
                          accent: accent,
                          onAddNode: _addNode,
                          callbacks: _callbacks,
                          worldAttributeKeys: world.attributeKeys,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bundles every node-editing callback the desktop/mobile bodies and the
/// shared `_NodeInspector` need, so `_CampaignMapScreenState` (the only
/// place that actually mutates a draft) hands them down explicitly instead
/// of child widgets reaching back up via `context.findAncestorStateOfType`.
typedef _NodeCallbacks = ({
  Future<void> Function(String id, String title) onRename,
  Future<void> Function(String id) onDelete,
  Future<void> Function(String id) onSetStart,
  Future<void> Function(String fromNodeId, {required String label, required String targetNodeId})
      onAddChoice,
  Future<void> Function(String fromNodeId, int index) onRemoveChoiceAt,
  Future<void> Function(String nodeId, String text) onBodyTextChanged,
  void Function(String what) onComingSoon,
  Future<void> Function(String nodeId, StoryNode node, {String? title}) onReplaceNode,
});

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.worldName,
    required this.published,
    required this.danglingCount,
    required this.saving,
    required this.updatedAt,
    required this.onBack,
    required this.onCover,
    required this.onPlaytest,
    required this.onPublish,
  });

  final String title;
  final String worldName;
  final bool published;
  final int danglingCount;
  final bool saving;
  final DateTime? updatedAt;
  final VoidCallback onBack;
  final VoidCallback onCover;
  final VoidCallback onPlaytest;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg),
      decoration: const BoxDecoration(
        color: AetherColors.ink,
        border: Border(bottom: BorderSide(color: AetherColors.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: AetherColors.goldSoft),
          ),
          const SizedBox(width: AetherSpace.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '$worldName · ${published ? 'publicada' : 'borrador'}',
                  style: EditorType.meta,
                ),
              ],
            ),
          ),
          const Spacer(),
          if (danglingCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm, vertical: 6),
              decoration: BoxDecoration(
                color: AetherColors.failure.withValues(alpha: 0.08),
                borderRadius: AetherRadius.allSm,
                border: Border.all(color: AetherColors.failure.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 15, color: AetherColors.failure),
                  const SizedBox(width: 6),
                  Text('$danglingCount cabo${danglingCount == 1 ? '' : 's'} suelto${danglingCount == 1 ? '' : 's'}',
                      style: EditorType.pill.copyWith(color: AetherColors.failure)),
                ],
              ),
            ),
            const SizedBox(width: AetherSpace.md),
          ],
          Text(
            saving
                ? 'Guardando…'
                : updatedAt == null
                    ? ''
                    : 'Guardado ${relativeTimeLabel(updatedAt!)}',
            style: EditorType.meta,
          ),
          const SizedBox(width: AetherSpace.md),
          IconButton(
            onPressed: onCover,
            tooltip: 'Portada e información',
            icon: const Icon(Icons.image_outlined, color: AetherColors.goldSoft),
          ),
          const SizedBox(width: AetherSpace.sm),
          OutlinedButton(
            onPressed: onPlaytest,
            style: OutlinedButton.styleFrom(
              foregroundColor: AetherColors.goldBright,
              side: const BorderSide(color: AetherColors.hairlineStrong),
              shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
            ),
            child: Text('Probar desde el inicio', style: EditorType.button),
          ),
          const SizedBox(width: AetherSpace.sm),
          FilledButton(
            onPressed: onPublish,
            style: FilledButton.styleFrom(
              backgroundColor: AetherColors.goldBright,
              foregroundColor: AetherColors.void_,
              shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
            ),
            child: Text('Publicar', style: EditorType.button.copyWith(color: AetherColors.void_)),
          ),
        ],
      ),
    );
  }
}

const _addSidebarItems = [
  (kind: NodeKind.fixedAnchor, label: 'Escena escrita', hint: 'Tú pones el texto'),
  (kind: NodeKind.boundedCorridor, label: 'Tramo libre', hint: 'Narra la IA, con límites'),
  (kind: NodeKind.stateHub, label: 'Alto en el camino', hint: 'Hacer cosas sin orden'),
  (kind: NodeKind.resolution, label: 'Final', hint: 'Cómo puede terminar'),
];

class _DesktopBody extends StatelessWidget {
  const _DesktopBody({
    required this.draft,
    required this.accent,
    required this.selectedNodeId,
    required this.onSelect,
    required this.onAddNode,
    required this.callbacks,
    required this.worldAttributeKeys,
  });

  final CampaignDraft draft;
  final Color accent;
  final String? selectedNodeId;
  final ValueChanged<String> onSelect;
  final ValueChanged<NodeKind> onAddNode;
  final _NodeCallbacks callbacks;
  final List<String> worldAttributeKeys;

  @override
  Widget build(BuildContext context) {
    final layers = CampaignGraphEdits.bfsLayers(draft.graph);
    final depths = layers.keys.toList()..sort();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Sidebar(draft: draft, selectedNodeId: selectedNodeId, onSelect: onSelect, onAddNode: onAddNode),
        Expanded(
          child: Container(
            color: AetherColors.void_,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(AetherSpace.xl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final depth in depths) ...[
                    _NodeColumn(
                      nodeIds: layers[depth]!,
                      draft: draft,
                      selectedNodeId: selectedNodeId,
                      onSelect: onSelect,
                    ),
                    const SizedBox(width: AetherSpace.xl),
                  ],
                  if (draft.graph.nodes.isEmpty) const _EmptyCanvasHint(),
                ],
              ),
            ),
          ),
        ),
        if (selectedNodeId != null)
          SizedBox(
            width: 340,
            child: _NodeInspector(
              key: ValueKey(selectedNodeId),
              draft: draft,
              nodeId: selectedNodeId!,
              callbacks: callbacks,
              worldAttributeKeys: worldAttributeKeys,
            ),
          ),
      ],
    );
  }
}

class _EmptyCanvasHint extends StatelessWidget {
  const _EmptyCanvasHint();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Padding(
        padding: const EdgeInsets.only(top: AetherSpace.huge),
        child: Column(
          children: [
            const Icon(Icons.auto_stories_rounded, size: 32, color: AetherColors.parchmentFaint),
            const SizedBox(height: AetherSpace.md),
            Text(
              'Añade una escena desde la izquierda para empezar tu historia.',
              style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.draft,
    required this.selectedNodeId,
    required this.onSelect,
    required this.onAddNode,
  });

  final CampaignDraft draft;
  final String? selectedNodeId;
  final ValueChanged<String> onSelect;
  final ValueChanged<NodeKind> onAddNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      padding: const EdgeInsets.symmetric(vertical: AetherSpace.lg, horizontal: AetherSpace.md),
      decoration: const BoxDecoration(
        color: AetherColors.ink,
        border: Border(right: BorderSide(color: AetherColors.hairline)),
      ),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AetherSpace.xs),
            child: Text('AÑADIR', style: EditorType.overline),
          ),
          const SizedBox(height: AetherSpace.sm),
          for (final item in _addSidebarItems)
            _AddNodeButton(
              color: switch (item.kind) {
                NodeKind.fixedAnchor => EditorNodeColors.fixedAnchor,
                NodeKind.boundedCorridor => EditorNodeColors.boundedCorridor,
                NodeKind.stateHub => EditorNodeColors.stateHub,
                NodeKind.resolution => EditorNodeColors.resolution,
              },
              icon: switch (item.kind) {
                NodeKind.fixedAnchor => Icons.edit_note_rounded,
                NodeKind.boundedCorridor => Icons.route_rounded,
                NodeKind.stateHub => Icons.hub_rounded,
                NodeKind.resolution => Icons.flag_rounded,
              },
              label: item.label,
              hint: item.hint,
              onTap: () => onAddNode(item.kind),
            ),
          const SizedBox(height: AetherSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AetherSpace.xs),
            child: Text('ESCENAS', style: EditorType.overline),
          ),
          const SizedBox(height: AetherSpace.xs),
          for (final entry in draft.graph.nodes.entries)
            _SceneRow(
              node: entry.value,
              title: draft.titleForNode(entry.key),
              isStart: entry.key == draft.graph.startNodeId,
              selected: entry.key == selectedNodeId,
              onTap: () => onSelect(entry.key),
            ),
        ],
      ),
    );
  }
}

class _AddNodeButton extends StatelessWidget {
  const _AddNodeButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 3, vertical: AetherSpace.sm + 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AetherSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: EditorType.label),
                  Text(hint, style: EditorType.hint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneRow extends StatelessWidget {
  const _SceneRow({
    required this.node,
    required this.title,
    required this.isStart,
    required this.selected,
    required this.onTap,
  });

  final StoryNode node;
  final String title;
  final bool isStart;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = EditorNodeColors.forNode(node);
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AetherColors.gold.withValues(alpha: 0.1) : null,
          borderRadius: AetherRadius.allSm,
        ),
        child: Row(
          children: [
            if (isStart)
              const Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(Icons.play_circle_rounded, size: 13, color: AetherColors.goldBright),
              ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EditorType.label.copyWith(
                  fontWeight: FontWeight.w500,
                  color: selected ? AetherColors.goldBright : AetherColors.parchmentDim,
                ),
              ),
            ),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}

class _NodeColumn extends StatelessWidget {
  const _NodeColumn({
    required this.nodeIds,
    required this.draft,
    required this.selectedNodeId,
    required this.onSelect,
  });

  final List<String> nodeIds;
  final CampaignDraft draft;
  final String? selectedNodeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final id in nodeIds)
          Padding(
            padding: const EdgeInsets.only(bottom: AetherSpace.lg),
            child: _NodeCard(
              node: draft.graph.nodes[id]!,
              title: draft.titleForNode(id),
              isStart: id == draft.graph.startNodeId,
              selected: id == selectedNodeId,
              onTap: () => onSelect(id),
              summary: _summaryFor(draft.graph.nodes[id]!, draft),
            ),
          ),
      ],
    );
  }

  String _summaryFor(StoryNode node, CampaignDraft draft) {
    return switch (node) {
      FixedAnchorNode(:final narration) => narration,
      BoundedCorridorNode(:final goal) => goal,
      StateHubNode(:final activities) => '${activities.length} cosas que hacer',
      ResolutionNode(:final endings) => '${endings.length} finales posibles',
    };
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.title,
    required this.isStart,
    required this.selected,
    required this.onTap,
    required this.summary,
  });

  final StoryNode node;
  final String title;
  final bool isStart;
  final bool selected;
  final VoidCallback onTap;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final color = EditorNodeColors.forNode(node);
    final targets = CampaignGraphEdits.outgoingTargets(node);
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(AetherSpace.md + 1),
        decoration: BoxDecoration(
          color: AetherColors.ink,
          borderRadius: AetherRadius.allMd,
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.32),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? AetherShadow.glow(color, strength: 0.35) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isStart) Icon(Icons.play_circle_rounded, size: 15, color: color),
                if (isStart) const SizedBox(width: 6),
                Icon(EditorNodeColors.kindIcon(node), size: 15, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (isStart ? 'EMPIEZA AQUÍ · ' : '') + EditorNodeColors.kindLabel(node).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EditorType.kicker.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AetherSpace.sm),
            Text(
              title,
              style: const TextStyle(fontFamily: 'Marcellus', fontSize: 15, color: AetherColors.goldSoft, height: 1.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (summary.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                summary,
                style: AetherType.caption.copyWith(fontSize: 11.5, color: AetherColors.parchmentFaint),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (node is FixedAnchorNode || node is BoundedCorridorNode || node is StateHubNode) ...[
              const SizedBox(height: AetherSpace.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MiniPill(text: '${targets.length} conexion${targets.length == 1 ? '' : 'es'}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AetherColors.gold.withValues(alpha: 0.1),
        borderRadius: AetherRadius.allSm,
      ),
      child: Text(text, style: EditorType.pill),
    );
  }
}

class _MobileBody extends StatefulWidget {
  const _MobileBody({
    required this.draft,
    required this.accent,
    required this.onAddNode,
    required this.callbacks,
    required this.worldAttributeKeys,
  });

  final CampaignDraft draft;
  final Color accent;
  final ValueChanged<NodeKind> onAddNode;
  final _NodeCallbacks callbacks;
  final List<String> worldAttributeKeys;

  @override
  State<_MobileBody> createState() => _MobileBodyState();
}

class _MobileBodyState extends State<_MobileBody> {
  @override
  Widget build(BuildContext context) {
    final entries = widget.draft.graph.nodes.entries.toList();
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
              AetherSpace.lg, AetherSpace.lg, AetherSpace.lg, 100),
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AetherSpace.huge),
                child: Text(
                  'Añade una escena para empezar tu historia.',
                  style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AetherSpace.sm),
                child: _MobileNodeRow(
                  node: entry.value,
                  title: widget.draft.titleForNode(entry.key),
                  isStart: entry.key == widget.draft.graph.startNodeId,
                  onTap: () => _openInspector(context, entry.key),
                ),
              ),
          ],
        ),
        Positioned(
          left: AetherSpace.lg,
          right: AetherSpace.lg,
          bottom: AetherSpace.lg,
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _pickNodeKind(context),
              style: FilledButton.styleFrom(
                backgroundColor: AetherColors.surfaceRaised,
                foregroundColor: AetherColors.goldBright,
                side: const BorderSide(color: AetherColors.hairlineStrong),
                shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text('Añadir una escena', style: EditorType.button.copyWith(fontSize: 13.5)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickNodeKind(BuildContext context) async {
    final kind = await showModalBottomSheet<NodeKind>(
      context: context,
      backgroundColor: AetherColors.ink,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AetherRadius.lg)),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AetherSpace.md),
            for (final item in _addSidebarItems)
              ListTile(
                leading: Icon(
                  switch (item.kind) {
                    NodeKind.fixedAnchor => Icons.edit_note_rounded,
                    NodeKind.boundedCorridor => Icons.route_rounded,
                    NodeKind.stateHub => Icons.hub_rounded,
                    NodeKind.resolution => Icons.flag_rounded,
                  },
                  color: switch (item.kind) {
                    NodeKind.fixedAnchor => EditorNodeColors.fixedAnchor,
                    NodeKind.boundedCorridor => EditorNodeColors.boundedCorridor,
                    NodeKind.stateHub => EditorNodeColors.stateHub,
                    NodeKind.resolution => EditorNodeColors.resolution,
                  },
                ),
                title: Text(item.label, style: EditorType.label),
                subtitle: Text(item.hint, style: EditorType.hint),
                onTap: () => Navigator.of(context).pop(item.kind),
              ),
            const SizedBox(height: AetherSpace.md),
          ],
        ),
      ),
    );
    if (kind != null) widget.onAddNode(kind);
  }

  Future<void> _openInspector(BuildContext context, String nodeId) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => Scaffold(
        backgroundColor: AetherColors.void_,
        appBar: AppBar(
          backgroundColor: AetherColors.ink,
          iconTheme: const IconThemeData(color: AetherColors.goldSoft),
          title: Text(widget.draft.titleForNode(nodeId),
              style: const TextStyle(fontFamily: 'Marcellus', color: AetherColors.goldBright, fontSize: 17)),
        ),
        body: _NodeInspector(
          draft: widget.draft,
          nodeId: nodeId,
          worldAttributeKeys: widget.worldAttributeKeys,
          callbacks: (
            onRename: widget.callbacks.onRename,
            onDelete: (id) async {
              await widget.callbacks.onDelete(id);
              if (routeContext.mounted) Navigator.of(routeContext).pop();
            },
            onSetStart: widget.callbacks.onSetStart,
            onAddChoice: widget.callbacks.onAddChoice,
            onRemoveChoiceAt: widget.callbacks.onRemoveChoiceAt,
            onBodyTextChanged: widget.callbacks.onBodyTextChanged,
            onComingSoon: widget.callbacks.onComingSoon,
            onReplaceNode: widget.callbacks.onReplaceNode,
          ),
        ),
      ),
    ));
  }
}

class _MobileNodeRow extends StatelessWidget {
  const _MobileNodeRow({
    required this.node,
    required this.title,
    required this.isStart,
    required this.onTap,
  });

  final StoryNode node;
  final String title;
  final bool isStart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = EditorNodeColors.forNode(node);
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Container(
        padding: const EdgeInsets.all(AetherSpace.md),
        decoration: BoxDecoration(
          color: AetherColors.ink,
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isStart) Icon(Icons.play_circle_rounded, size: 15, color: color),
                if (isStart) const SizedBox(width: 6),
                Icon(EditorNodeColors.kindIcon(node), size: 15, color: color),
                const SizedBox(width: 6),
                Text(EditorNodeColors.kindLabel(node).toUpperCase(),
                    style: EditorType.kicker.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: AetherSpace.sm),
            Text(title,
                style: const TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldSoft)),
          ],
        ),
      ),
    );
  }
}

/// The selected node's editing panel — desktop side panel and the mobile
/// full-screen push both render this same widget (V2 design prototype
/// §9a's right column). See the file doc comment for what's real vs.
/// "próximamente" at this stage.
class _NodeInspector extends StatefulWidget {
  const _NodeInspector({
    super.key,
    required this.draft,
    required this.nodeId,
    required this.callbacks,
    required this.worldAttributeKeys,
  });

  final CampaignDraft draft;
  final String nodeId;
  final _NodeCallbacks callbacks;
  final List<String> worldAttributeKeys;

  @override
  State<_NodeInspector> createState() => _NodeInspectorState();
}

class _NodeInspectorState extends State<_NodeInspector> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.draft.titleForNode(widget.nodeId));
  late final TextEditingController _bodyController = TextEditingController(text: _initialBody());
  Timer? _debounce;

  String _initialBody() {
    final node = widget.draft.graph.nodes[widget.nodeId];
    return switch (node) {
      FixedAnchorNode(:final narration) => narration,
      _ => '',
    };
  }

  /// Every other node's title, for a target-node dropdown — self excluded
  /// only where a choice/exit genuinely shouldn't loop back to its own
  /// scene by construction (kept permissive elsewhere; a self-loop is
  /// unusual but not invalid).
  Map<String, String> get _nodeTitles => {
        for (final id in widget.draft.graph.nodes.keys) id: widget.draft.titleForNode(id),
      };

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.callbacks.onRename(widget.nodeId, value.trim());
    });
  }

  void _onBodyChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.callbacks.onBodyTextChanged(widget.nodeId, value);
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AetherColors.surface,
        title: Text('¿Eliminar esta escena?', style: AetherType.title.copyWith(fontSize: 16)),
        content: Text(
          'También se quitan las conexiones que otras escenas tenían hacia ella.',
          style: AetherType.body.copyWith(fontSize: 13, color: AetherColors.parchmentDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: EditorType.button.copyWith(color: AetherColors.parchmentDim)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar', style: EditorType.button.copyWith(color: AetherColors.failure)),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.callbacks.onDelete(widget.nodeId);
  }

  Future<void> _addChoice(StoryNode node) async {
    final choice = await ChoiceEditorScreen.open(
      context,
      initial: null,
      nodeTitles: _nodeTitles,
      worldAttributeKeys: widget.worldAttributeKeys,
      accent: EditorNodeColors.forNode(node),
    );
    if (choice == null) return;
    await widget.callbacks.onReplaceNode(
      widget.nodeId,
      CampaignGraphEdits.withAddedChoice(node, choice),
    );
  }

  Future<void> _editChoiceAt(StoryNode node, int index, StoryChoice existing) async {
    final choice = await ChoiceEditorScreen.open(
      context,
      initial: existing,
      nodeTitles: _nodeTitles,
      worldAttributeKeys: widget.worldAttributeKeys,
      accent: EditorNodeColors.forNode(node),
    );
    if (choice == null) return;
    await widget.callbacks.onReplaceNode(
      widget.nodeId,
      CampaignGraphEdits.withChoiceReplacedAt(node, index, choice),
    );
  }

  Future<void> _editCorridor(BoundedCorridorNode node) async {
    final result = await CorridorEditorScreen.open(
      context,
      initialTitle: widget.draft.titleForNode(widget.nodeId),
      initialNode: node,
      nodeTitles: _nodeTitles,
      worldAttributeKeys: widget.worldAttributeKeys,
    );
    if (result == null) return;
    await widget.callbacks.onReplaceNode(widget.nodeId, result.node, title: result.title);
  }

  Future<void> _editHub(StateHubNode node) async {
    final result = await HubEditorScreen.open(
      context,
      initialTitle: widget.draft.titleForNode(widget.nodeId),
      initialNode: node,
      nodeTitles: _nodeTitles,
      worldAttributeKeys: widget.worldAttributeKeys,
    );
    if (result == null) return;
    await widget.callbacks.onReplaceNode(widget.nodeId, result.node, title: result.title);
  }

  Future<void> _addEnding(ResolutionNode node) async {
    final ending = await EndingEditorScreen.open(
      context,
      initial: null,
      indexLabel: node.endings.length + 1,
      totalCount: node.endings.length + 1,
      resolutionTitle: widget.draft.titleForNode(widget.nodeId),
      worldAttributeKeys: widget.worldAttributeKeys,
    );
    if (ending == null) return;
    await widget.callbacks.onReplaceNode(
      widget.nodeId,
      ResolutionNode(
        id: node.id,
        narration: node.narration,
        endings: [...node.endings, ending],
        epilogueBeats: node.epilogueBeats,
        finalTechniqueRules: node.finalTechniqueRules,
        epilogueNodeId: node.epilogueNodeId,
        codexReveals: node.codexReveals,
      ),
    );
  }

  Future<void> _editEndingAt(ResolutionNode node, int index) async {
    final ending = await EndingEditorScreen.open(
      context,
      initial: node.endings[index],
      indexLabel: index + 1,
      totalCount: node.endings.length,
      resolutionTitle: widget.draft.titleForNode(widget.nodeId),
      worldAttributeKeys: widget.worldAttributeKeys,
    );
    if (ending == null) return;
    final updatedEndings = [...node.endings];
    updatedEndings[index] = ending;
    await widget.callbacks.onReplaceNode(
      widget.nodeId,
      ResolutionNode(
        id: node.id,
        narration: node.narration,
        endings: updatedEndings,
        epilogueBeats: node.epilogueBeats,
        finalTechniqueRules: node.finalTechniqueRules,
        epilogueNodeId: node.epilogueNodeId,
        codexReveals: node.codexReveals,
      ),
    );
  }

  Future<void> _removeEndingAt(ResolutionNode node, int index) async {
    final updatedEndings = [...node.endings]..removeAt(index);
    await widget.callbacks.onReplaceNode(
      widget.nodeId,
      ResolutionNode(
        id: node.id,
        narration: node.narration,
        endings: updatedEndings,
        epilogueBeats: node.epilogueBeats,
        finalTechniqueRules: node.finalTechniqueRules,
        epilogueNodeId: node.epilogueNodeId,
        codexReveals: node.codexReveals,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.draft.graph.nodes[widget.nodeId];
    if (node == null) return const SizedBox.shrink();
    final color = EditorNodeColors.forNode(node);
    final isStart = widget.nodeId == widget.draft.graph.startNodeId;

    return Container(
      decoration: const BoxDecoration(
        color: AetherColors.ink,
        border: Border(left: BorderSide(color: AetherColors.hairline)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AetherSpace.lg),
        children: [
          Row(
            children: [
              Icon(EditorNodeColors.kindIcon(node), size: 16, color: color),
              const SizedBox(width: 6),
              Text(EditorNodeColors.kindLabel(node), style: EditorType.overline.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: AetherSpace.sm),
          TextField(
            controller: _titleController,
            onChanged: _onTitleChanged,
            style: const TextStyle(fontFamily: 'Marcellus', fontSize: 19, color: AetherColors.goldBright),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
          ),
          const SizedBox(height: AetherSpace.md),
          if (!isStart)
            OutlinedButton.icon(
              onPressed: () => widget.callbacks.onSetStart(widget.nodeId),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
              label: Text('Marcar como inicio', style: EditorType.button.copyWith(fontSize: 11.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AetherColors.goldSoft,
                side: const BorderSide(color: AetherColors.hairline),
                shape: RoundedRectangleBorder(borderRadius: AetherRadius.allSm),
                padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm, vertical: 6),
              ),
            ),
          const SizedBox(height: AetherSpace.lg),
          switch (node) {
            FixedAnchorNode() => _FixedAnchorSection(
                node: node,
                bodyController: _bodyController,
                onBodyChanged: _onBodyChanged,
                onFixedRevealsChanged: (v) => widget.callbacks
                    .onReplaceNode(widget.nodeId, CampaignGraphEdits.withFixedReveals(node, v)),
                onForbiddenRevealsChanged: (v) => widget.callbacks
                    .onReplaceNode(widget.nodeId, CampaignGraphEdits.withForbiddenReveals(node, v)),
                onAddChoice: () => _addChoice(node),
                onEditChoiceAt: (i) => _editChoiceAt(node, i, node.choices[i]),
                onRemoveChoiceAt: (i) => widget.callbacks.onRemoveChoiceAt(widget.nodeId, i),
                nodeTitles: _nodeTitles,
              ),
            BoundedCorridorNode() => _CorridorSection(
                node: node,
                onEdit: () => _editCorridor(node),
              ),
            StateHubNode() => _HubSection(
                node: node,
                onEdit: () => _editHub(node),
              ),
            ResolutionNode() => _ResolutionSection(
                node: node,
                onAdd: () => _addEnding(node),
                onEditAt: (i) => _editEndingAt(node, i),
                onRemoveAt: (i) => _removeEndingAt(node, i),
              ),
          },
          const SizedBox(height: AetherSpace.md),
          const Divider(color: AetherColors.hairline),
          const SizedBox(height: AetherSpace.sm),
          OutlinedButton.icon(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: Text('Eliminar escena', style: EditorType.button.copyWith(fontSize: 11.5)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AetherColors.failure,
              side: BorderSide(color: AetherColors.failure.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: AetherRadius.allSm),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedAnchorSection extends StatelessWidget {
  const _FixedAnchorSection({
    required this.node,
    required this.bodyController,
    required this.onBodyChanged,
    required this.onFixedRevealsChanged,
    required this.onForbiddenRevealsChanged,
    required this.onAddChoice,
    required this.onEditChoiceAt,
    required this.onRemoveChoiceAt,
    required this.nodeTitles,
  });

  final FixedAnchorNode node;
  final TextEditingController bodyController;
  final ValueChanged<String> onBodyChanged;
  final ValueChanged<List<String>> onFixedRevealsChanged;
  final ValueChanged<List<String>> onForbiddenRevealsChanged;
  final VoidCallback onAddChoice;
  final ValueChanged<int> onEditChoiceAt;
  final ValueChanged<int> onRemoveChoiceAt;
  final Map<String, String> nodeTitles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lo que se lee al llegar', style: EditorType.overline),
        const SizedBox(height: AetherSpace.sm),
        Container(
          padding: const EdgeInsets.all(AetherSpace.sm + 4),
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: AetherColors.hairline),
          ),
          child: TextField(
            controller: bodyController,
            onChanged: onBodyChanged,
            maxLines: null,
            minLines: 3,
            style: AetherType.body.copyWith(fontSize: 13.5),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
          ),
        ),
        const SizedBox(height: AetherSpace.lg),
        Text('El narrador debe decir', style: EditorType.overline),
        const SizedBox(height: AetherSpace.sm),
        ChipListField(
          values: node.fixedReveals,
          accent: AetherColors.success,
          onChanged: onFixedRevealsChanged,
        ),
        const SizedBox(height: AetherSpace.md),
        Text('Todavía no puede revelar', style: EditorType.overline),
        const SizedBox(height: AetherSpace.sm),
        ChipListField(
          values: node.forbiddenReveals,
          accent: AetherColors.failure,
          onChanged: onForbiddenRevealsChanged,
        ),
        const SizedBox(height: AetherSpace.lg),
        Row(
          children: [
            Expanded(child: Text('Qué puede hacer el jugador', style: EditorType.overline)),
            InkWell(
              onTap: onAddChoice,
              child: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AetherColors.goldBright),
            ),
          ],
        ),
        const SizedBox(height: AetherSpace.sm),
        for (final (i, choice) in node.choices.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AetherSpace.sm),
            child: _ChoiceRow(
              choice: choice,
              targetTitle: nodeTitles[choice.targetNodeId] ?? choice.targetNodeId,
              onEdit: () => onEditChoiceAt(i),
              onRemove: () => onRemoveChoiceAt(i),
            ),
          ),
        if (node.choices.isEmpty) Text('Todavía no hay ninguna.', style: AetherType.caption),
      ],
    );
  }
}

class _CorridorSection extends StatelessWidget {
  const _CorridorSection({required this.node, required this.onEdit});

  final BoundedCorridorNode node;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    const accent = EditorNodeColors.boundedCorridor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Qué tiene que conseguir el jugador', style: EditorType.overline),
        const SizedBox(height: AetherSpace.sm),
        Text(
          node.goal.isEmpty ? 'Sin meta todavía.' : node.goal,
          style: AetherType.body.copyWith(fontSize: 13),
        ),
        const SizedBox(height: AetherSpace.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _SummaryPill(text: '${node.turnBudget} turnos', color: accent),
            _SummaryPill(
              text: node.fallbackExitNodeId.isEmpty ? 'sin salida asignada' : 'tiene salida',
              color: node.fallbackExitNodeId.isEmpty ? AetherColors.failure : accent,
            ),
            _SummaryPill(text: '${node.choices.length} salidas explícitas', color: accent),
          ],
        ),
        const SizedBox(height: AetherSpace.md),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.tune_rounded, size: 16),
          label: Text('Editar tramo', style: EditorType.button.copyWith(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: AetherRadius.allSm),
          ),
        ),
      ],
    );
  }
}

class _HubSection extends StatelessWidget {
  const _HubSection({required this.node, required this.onEdit});

  final StateHubNode node;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    const accent = EditorNodeColors.stateHub;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _SummaryPill(text: '${node.activities.length} cosas que hacer', color: accent),
            _SummaryPill(text: '${node.exits.length} salidas', color: accent),
          ],
        ),
        const SizedBox(height: AetherSpace.md),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.tune_rounded, size: 16),
          label: Text('Editar alto', style: EditorType.button.copyWith(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: AetherRadius.allSm),
          ),
        ),
      ],
    );
  }
}

class _ResolutionSection extends StatelessWidget {
  const _ResolutionSection({
    required this.node,
    required this.onAdd,
    required this.onEditAt,
    required this.onRemoveAt,
  });

  final ResolutionNode node;
  final VoidCallback onAdd;
  final ValueChanged<int> onEditAt;
  final ValueChanged<int> onRemoveAt;

  @override
  Widget build(BuildContext context) {
    const accent = EditorNodeColors.resolution;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Finales posibles', style: EditorType.overline)),
            InkWell(
              onTap: onAdd,
              child: const Icon(Icons.add_circle_outline_rounded, size: 18, color: accent),
            ),
          ],
        ),
        const SizedBox(height: AetherSpace.sm),
        if (node.endings.isEmpty) Text('Todavía no hay ninguno.', style: AetherType.caption),
        for (final (i, ending) in node.endings.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AetherSpace.sm),
            child: InkWell(
              onTap: () => onEditAt(i),
              borderRadius: AetherRadius.allMd,
              child: Container(
                padding: const EdgeInsets.all(AetherSpace.sm + 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.05),
                  borderRadius: AetherRadius.allMd,
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ending.visibleChoice.isEmpty ? '(sin texto)' : ending.visibleChoice,
                        style: AetherType.body.copyWith(fontSize: 12.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => onRemoveAt(i),
                      child: const Icon(Icons.close_rounded, size: 16, color: AetherColors.parchmentFaint),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AetherRadius.allSm,
      ),
      child: Text(text, style: EditorType.pill.copyWith(color: color)),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.choice,
    required this.targetTitle,
    required this.onEdit,
    required this.onRemove,
  });

  final StoryChoice choice;
  final String targetTitle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: AetherRadius.allSm,
      child: Container(
        padding: const EdgeInsets.all(AetherSpace.sm + 2),
        decoration: BoxDecoration(
          color: AetherColors.surface,
          borderRadius: AetherRadius.allSm,
          border: Border.all(color: AetherColors.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(choice.label, style: AetherType.body.copyWith(fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.arrow_forward_rounded, size: 12, color: AetherColors.parchmentFaint),
                      const SizedBox(width: 4),
                      Text(targetTitle, style: EditorType.pill),
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded, size: 16, color: AetherColors.parchmentFaint),
            ),
          ],
        ),
      ),
    );
  }
}
