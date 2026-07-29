import 'package:flutter/material.dart';

import '../../core/engine/action_resolution.dart';
import '../../core/narrative/checkable.dart';
import '../../core/narrative/hub_activity.dart';
import '../../core/narrative/story_graph.dart';
import '../../core/narrative/story_node.dart';
import '../../core/world/world.dart';
import '../design/breakpoints.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'design/editor_tokens.dart';
import 'playtest/campaign_playtest_controller.dart';

/// "Probar el borrador" (V2 design prototype §9j) — a real playthrough of
/// the draft graph, but with the state panel visible and editable (jump to
/// any scene, force a dice result, flip flags). Nothing here is a
/// `GameSession`; see `CampaignPlaytestController`'s doc comment for why
/// that boundary is what makes this safe to ship inside the player binary.
class PlaytestScreen extends StatefulWidget {
  const PlaytestScreen({
    super.key,
    required this.graph,
    required this.world,
    required this.nodeTitles,
    this.startNodeId,
  });

  final StoryGraph graph;
  final World world;
  final Map<String, String> nodeTitles;

  /// Where to start the playtest — defaults to the graph's own start when
  /// `null` (opened from the header's "Probar desde el inicio").
  final String? startNodeId;

  @override
  State<PlaytestScreen> createState() => _PlaytestScreenState();
}

class _PlaytestScreenState extends State<PlaytestScreen> {
  late final CampaignPlaytestController _controller = CampaignPlaytestController(
    graph: widget.graph,
    world: widget.world,
    nodeTitles: widget.nodeTitles,
  )..restart(widget.startNodeId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.void_,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            children: [
              _PlaytestBanner(
                onRestart: () => _controller.restart(),
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final scene = _ScenePane(controller: _controller);
                    final panel = _DebugPanel(controller: _controller);
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: scene),
                          SizedBox(width: 330, child: panel),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(child: scene),
                        SizedBox(height: 280, child: panel),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaytestBanner extends StatelessWidget {
  const _PlaytestBanner({required this.onRestart, required this.onBack});

  final VoidCallback onRestart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg),
      color: const Color(0xFFD8B65E).withValues(alpha: 0.12),
      // The full sentence + both labeled actions never fit a 375px row (the
      // same overflow-banner-on-top-of-the-overflow-warning irony this
      // fixes elsewhere) -- below the tablet breakpoint, the explanatory
      // sentence drops and "restart" shrinks to icon-only; "Volver al
      // mapa" stays labeled since it's the one way out of playtest mode.
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < AetherBreakpoints.tablet;
        return Row(
          children: [
            const Icon(Icons.science_rounded, size: 17, color: Color(0xFFD8B65E)),
            const SizedBox(width: AetherSpace.sm),
            Text(compact ? 'PRUEBA' : 'ESTÁS PROBANDO UN BORRADOR',
                style: EditorType.overline.copyWith(color: const Color(0xFFD8B65E), letterSpacing: 1.6)),
            const SizedBox(width: AetherSpace.md),
            if (!compact)
              Expanded(
                child: Text('Nada de esto se guarda como partida', style: EditorType.meta),
              )
            else
              const Spacer(),
            if (compact)
              IconButton(
                onPressed: onRestart,
                tooltip: 'Empezar de nuevo',
                icon: const Icon(Icons.restart_alt_rounded, size: 18, color: AetherColors.parchmentDim),
              )
            else
              InkWell(
                onTap: onRestart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restart_alt_rounded, size: 16, color: AetherColors.parchmentDim),
                    const SizedBox(width: 6),
                    Text('Empezar de nuevo',
                        style: EditorType.button.copyWith(color: AetherColors.parchmentDim)),
                  ],
                ),
              ),
            SizedBox(width: compact ? AetherSpace.sm : AetherSpace.lg),
            InkWell(
              onTap: onBack,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_rounded, size: 16, color: AetherColors.goldBright),
                  const SizedBox(width: 6),
                  Text('Volver al mapa', style: EditorType.button.copyWith(color: AetherColors.goldBright)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ScenePane extends StatelessWidget {
  const _ScenePane({required this.controller});

  final CampaignPlaytestController controller;

  @override
  Widget build(BuildContext context) {
    final node = controller.currentNode;
    final color = _accentFor(node);
    return Container(
      color: const Color(0xFF080F0E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AetherSpace.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.22), const Color(0xFF080F0E)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_kindLabel(node).toUpperCase(),
                          style: EditorType.overline.copyWith(color: color, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(controller.titleFor(controller.currentNodeId),
                          style: TextStyle(fontFamily: 'Marcellus', fontSize: 24, color: color)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080F0E).withValues(alpha: 0.7),
                    borderRadius: AetherRadius.allSm,
                    border: Border.all(color: const Color(0xFFD8B65E).withValues(alpha: 0.35)),
                  ),
                  child: Text('turno ${controller.path.length} de prueba',
                      style: EditorType.pill.copyWith(color: const Color(0xFFD8B65E))),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AetherSpace.lg, AetherSpace.md, AetherSpace.lg, AetherSpace.xl),
              child: _SceneBody(controller: controller, color: color),
            ),
          ),
        ],
      ),
    );
  }

  static Color _accentFor(StoryNode node) => switch (node) {
        FixedAnchorNode() => AetherColors.goldBright,
        BoundedCorridorNode() => const Color(0xFF7FD4C1),
        StateHubNode() => const Color(0xFF55E0F0),
        ResolutionNode() => const Color(0xFFB98DEB),
      };

  static String _kindLabel(StoryNode node) => switch (node) {
        FixedAnchorNode() => 'Escena escrita',
        BoundedCorridorNode() => 'Tramo libre',
        StateHubNode() => 'Alto en el camino',
        ResolutionNode() => 'Final',
      };
}

class _SceneBody extends StatelessWidget {
  const _SceneBody({required this.controller, required this.color});

  final CampaignPlaytestController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final node = controller.currentNode;

    if (controller.isEnded) {
      return _EndedCard(text: controller.lastResultText ?? 'Fin de la prueba.');
    }
    if (controller.epilogueBeats != null) {
      return _EpilogueCard(beats: controller.epilogueBeats!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (node is FixedAnchorNode) ...[
          if (node.narration.isNotEmpty)
            Text(node.narration, style: AetherType.narration.copyWith(fontSize: 15, color: const Color(0xFFDCEBE7))),
        ] else if (node is BoundedCorridorNode) ...[
          Text('Meta de este tramo (no hay narrador de IA en la prueba):',
              style: EditorType.overline.copyWith(color: color)),
          const SizedBox(height: 6),
          Text(node.goal, style: AetherType.narration.copyWith(fontSize: 15, color: const Color(0xFFDCEBE7))),
        ] else if (node is StateHubNode) ...[
          Text('Elegí qué hacer, en el orden que quieras.', style: AetherType.caption),
        ],
        if (controller.lastResultText != null && node is! FixedAnchorNode) ...[
          const SizedBox(height: AetherSpace.md),
          Container(
            padding: const EdgeInsets.all(AetherSpace.sm + 2),
            decoration: BoxDecoration(
              color: AetherColors.surfaceRaised,
              borderRadius: AetherRadius.allMd,
            ),
            child: Text(controller.lastResultText!,
                style: AetherType.body.copyWith(fontSize: 13, fontStyle: FontStyle.italic)),
          ),
        ],
        if (controller.lastResolution != null) ...[
          const SizedBox(height: AetherSpace.md),
          _RollCard(resolution: controller.lastResolution!),
        ],
        const SizedBox(height: AetherSpace.lg),
        if (node is StateHubNode) ...[
          for (final activity in controller.availableActivities)
            Padding(
              padding: const EdgeInsets.only(bottom: AetherSpace.sm),
              child: _ActivityRow(
                activity: activity,
                usedUp: controller.isActivityUsedUp(activity),
                color: color,
                onTap: controller.isActivityUsedUp(activity)
                    ? null
                    : () => controller.chooseActivity(activity),
              ),
            ),
          if (controller.availableActivities.isNotEmpty) const SizedBox(height: AetherSpace.md),
          Text('SALIDAS', style: EditorType.overline.copyWith(color: color)),
          const SizedBox(height: AetherSpace.sm),
        ],
        for (final action in controller.availableActions)
          Padding(
            padding: const EdgeInsets.only(bottom: AetherSpace.sm),
            child: _ActionRow(
              checkable: action,
              label: action.label,
              targetTitle: controller.titleFor(action.targetNodeId),
              color: color,
              onTap: () => controller.chooseAction(action),
            ),
          ),
        if (node is BoundedCorridorNode)
          Padding(
            padding: const EdgeInsets.only(top: AetherSpace.sm),
            child: OutlinedButton.icon(
              onPressed: controller.useFallbackExit,
              icon: const Icon(Icons.exit_to_app_rounded, size: 16),
              label: Text('Usar la salida forzada → ${controller.titleFor(node.fallbackExitNodeId)}',
                  style: EditorType.button.copyWith(fontSize: 11.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: AetherRadius.allSm),
              ),
            ),
          ),
        if (node is ResolutionNode)
          for (final ending in controller.availableEndings)
            Padding(
              padding: const EdgeInsets.only(bottom: AetherSpace.sm),
              child: _ActionRow(
                checkable: null,
                label: ending.visibleChoice,
                targetTitle: null,
                color: color,
                onTap: () => controller.chooseEnding(ending),
              ),
            ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.checkable,
    required this.label,
    required this.targetTitle,
    required this.color,
    required this.onTap,
  });

  final Checkable? checkable;
  final String label;
  final String? targetTitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm + 3),
        decoration: BoxDecoration(
          color: const Color(0xFF111A18).withValues(alpha: 0.6),
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            if (checkable?.requiresCheck ?? false)
              const Padding(
                padding: EdgeInsets.only(right: AetherSpace.sm),
                child: Icon(Icons.casino_rounded, size: 17, color: Color(0xFFD8B65E)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AetherType.body.copyWith(fontSize: 13.5, color: const Color(0xFFDCEBE7))),
                  if (checkable?.requiresCheck ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('${checkable!.checkAttribute} · dificultad ${checkable!.checkDifficulty}',
                          style: EditorType.pill.copyWith(color: const Color(0xFFD8B65E))),
                    ),
                ],
              ),
            ),
            if (targetTitle != null) ...[
              const Icon(Icons.arrow_forward_rounded, size: 14, color: AetherColors.parchmentFaint),
              const SizedBox(width: 4),
              Text(targetTitle!, style: EditorType.pill),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.usedUp,
    required this.color,
    required this.onTap,
  });

  final HubActivity activity;
  final bool usedUp;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: usedUp ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: AetherRadius.allMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm + 3),
          decoration: BoxDecoration(
            color: const Color(0xFF111A18).withValues(alpha: 0.6),
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(activity.label,
                    style: AetherType.body.copyWith(fontSize: 13.5, color: const Color(0xFFDCEBE7))),
              ),
              Text(usedUp ? 'usada' : (activity.repeatable ? 'se puede repetir' : 'una sola vez'),
                  style: EditorType.pill),
            ],
          ),
        ),
      ),
    );
  }
}

class _RollCard extends StatelessWidget {
  const _RollCard({required this.resolution});

  final ActionResolution resolution;

  @override
  Widget build(BuildContext context) {
    final outcomeLabel = switch (resolution.outcome) {
      ActionOutcome.criticalSuccess => 'Éxito crítico',
      ActionOutcome.success => 'Éxito',
      ActionOutcome.failure => 'Fracaso',
    };
    final outcomeColor = switch (resolution.outcome) {
      ActionOutcome.criticalSuccess => AetherColors.goldBright,
      ActionOutcome.success => AetherColors.success,
      ActionOutcome.failure => AetherColors.failure,
    };
    return Container(
      padding: const EdgeInsets.all(AetherSpace.sm + 3),
      decoration: BoxDecoration(
        color: outcomeColor.withValues(alpha: 0.06),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: outcomeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(outcomeLabel, style: EditorType.label.copyWith(color: outcomeColor)),
          const SizedBox(width: AetherSpace.sm),
          Text(
            '${resolution.attributeKey} ${resolution.attribute} + tirada ${resolution.roll} = '
            '${resolution.total} vs. dificultad ${resolution.difficulty}',
            style: EditorType.meta,
          ),
        ],
      ),
    );
  }
}

class _EndedCard extends StatelessWidget {
  const _EndedCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFB98DEB).withValues(alpha: 0.06),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: const Color(0xFFB98DEB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FIN DE LA PRUEBA',
              style: TextStyle(fontFamily: 'Archivo', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: Color(0xFFB98DEB))),
          const SizedBox(height: AetherSpace.sm),
          Text(text, style: AetherType.narration.copyWith(fontSize: 14, color: const Color(0xFFDCEBE7))),
        ],
      ),
    );
  }
}

class _EpilogueCard extends StatelessWidget {
  const _EpilogueCard({required this.beats});

  final List<String> beats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFB98DEB).withValues(alpha: 0.06),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: const Color(0xFFB98DEB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EPÍLOGO',
              style: TextStyle(fontFamily: 'Archivo', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: Color(0xFFB98DEB))),
          const SizedBox(height: AetherSpace.sm),
          for (final beat in beats)
            Padding(
              padding: const EdgeInsets.only(bottom: AetherSpace.sm),
              child: Text(beat, style: AetherType.narration.copyWith(fontSize: 14, color: const Color(0xFFDCEBE7))),
            ),
          if (beats.isEmpty)
            Text('Este epílogo no tiene texto para el estado actual.', style: AetherType.caption),
        ],
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.controller});

  final CampaignPlaytestController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AetherColors.ink,
        border: Border(left: BorderSide(color: AetherColors.hairline)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AetherSpace.lg),
        children: [
          Text('EMPEZAR LA PRUEBA EN', style: EditorType.overline),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2),
            decoration: BoxDecoration(
              color: AetherColors.surface,
              borderRadius: AetherRadius.allSm,
              border: Border.all(color: AetherColors.hairline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: controller.currentNodeId,
                isExpanded: true,
                dropdownColor: AetherColors.surface,
                style: AetherType.body.copyWith(fontSize: 12.5, color: AetherColors.parchment),
                items: [
                  for (final id in controller.allNodeIds)
                    DropdownMenuItem(value: id, child: Text(controller.titleFor(id))),
                ],
                onChanged: (id) {
                  if (id != null) controller.restart(id);
                },
              ),
            ),
          ),
          const SizedBox(height: AetherSpace.lg),
          Text('EL DADO', style: EditorType.overline),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final mode in PlaytestDiceMode.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DiceModeButton(
                      mode: mode,
                      selected: controller.diceMode == mode,
                      onTap: () => controller.setDiceMode(mode),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AetherSpace.lg),
          Text('EL PERSONAJE DE PRUEBA', style: EditorType.overline),
          const SizedBox(height: 8),
          for (final key in controller.character.attributes.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _AttributeStepper(
                label: key,
                value: controller.character.attribute(key),
                onChanged: (delta) => controller.adjustAttribute(key, delta),
              ),
            ),
          if (controller.flagKeys.isNotEmpty) ...[
            const SizedBox(height: AetherSpace.lg),
            Text('LO QUE YA PASÓ', style: EditorType.overline),
            const SizedBox(height: 8),
            for (final key in controller.flagKeys)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _FlagToggle(
                  label: key,
                  value: controller.character.flag(key),
                  onChanged: (_) => controller.toggleFlag(key),
                ),
              ),
          ],
          const SizedBox(height: AetherSpace.lg),
          Text('POR DÓNDE HAS PASADO', style: EditorType.overline),
          const SizedBox(height: 8),
          for (final (i, id) in controller.path.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text('${i + 1} ·', style: EditorType.meta),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      controller.titleFor(id),
                      style: EditorType.label.copyWith(
                        fontSize: 11.5,
                        color: id == controller.currentNodeId
                            ? AetherColors.goldBright
                            : AetherColors.parchmentDim,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DiceModeButton extends StatelessWidget {
  const _DiceModeButton({required this.mode, required this.selected, required this.onTap});

  final PlaytestDiceMode mode;
  final bool selected;
  final VoidCallback onTap;

  Color get _color => switch (mode) {
        PlaytestDiceMode.random => AetherColors.goldBright,
        PlaytestDiceMode.forceSuccess => AetherColors.success,
        PlaytestDiceMode.forceFailure => AetherColors.failure,
        PlaytestDiceMode.force20 => AetherColors.goldBright,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allSm,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _color.withValues(alpha: 0.16) : null,
          borderRadius: AetherRadius.allSm,
          border: Border.all(color: selected ? _color.withValues(alpha: 0.5) : AetherColors.hairline),
        ),
        child: Text(
          mode.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Archivo',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: selected ? _color : AetherColors.parchmentFaint,
          ),
        ),
      ),
    );
  }
}

class _AttributeStepper extends StatelessWidget {
  const _AttributeStepper({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2, vertical: 6),
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allSm,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AetherType.body.copyWith(fontSize: 12))),
          InkWell(
            onTap: () => onChanged(-1),
            child: const Icon(Icons.remove_rounded, size: 16, color: AetherColors.parchmentFaint),
          ),
          SizedBox(
            width: 24,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: AetherType.body.copyWith(fontWeight: FontWeight.w700)),
          ),
          InkWell(
            onTap: () => onChanged(1),
            child: const Icon(Icons.add_rounded, size: 16, color: AetherColors.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

class _FlagToggle extends StatelessWidget {
  const _FlagToggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2, vertical: 4),
      decoration: BoxDecoration(
        color: value ? AetherColors.success.withValues(alpha: 0.05) : AetherColors.surface,
        borderRadius: AetherRadius.allSm,
        border: Border.all(color: value ? AetherColors.success.withValues(alpha: 0.3) : AetherColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AetherType.body.copyWith(fontSize: 11.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AetherColors.success),
        ],
      ),
    );
  }
}
