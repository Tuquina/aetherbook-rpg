import 'package:flutter/material.dart';

import '../../core/narrative/story_choice.dart';
import '../../core/narrative/story_node.dart';
import '../design/breakpoints.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'choice_editor_screen.dart';
import 'design/editor_tokens.dart';
import 'widgets/chip_list_field.dart';
import 'widgets/node_target_dropdown.dart';

typedef CorridorEditResult = ({String title, BoundedCorridorNode node});

/// Editing surface for a [BoundedCorridorNode] (V2 design prototype §9g,
/// "Tramo libre") — the goal, the turn budget, the forced fallback exit, the
/// AI's guardrail chip-lists, and any explicit early exits.
class CorridorEditorScreen {
  const CorridorEditorScreen._();

  static Future<CorridorEditResult?> open(
    BuildContext context, {
    required String initialTitle,
    required BoundedCorridorNode initialNode,
    required Map<String, String> nodeTitles,
    required List<String> worldAttributeKeys,
  }) {
    const accent = EditorNodeColors.boundedCorridor;
    final desktop = MediaQuery.sizeOf(context).width >= AetherBreakpoints.desktop;
    final content = _CorridorForm(
      initialTitle: initialTitle,
      initialNode: initialNode,
      nodeTitles: nodeTitles,
      worldAttributeKeys: worldAttributeKeys,
    );
    if (desktop) {
      return showDialog<CorridorEditResult>(
        context: context,
        builder: (_) => _CorridorDialogChrome(accent: accent, child: content),
      );
    }
    return Navigator.of(context).push<CorridorEditResult>(
      MaterialPageRoute(builder: (_) => _CorridorPageChrome(accent: accent, child: content)),
    );
  }
}

class _CorridorDialogChrome extends StatelessWidget {
  const _CorridorDialogChrome({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AetherSpace.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 800),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B1210),
            borderRadius: AetherRadius.allLg,
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg),
                decoration: const BoxDecoration(
                  color: Color(0xFF111A18),
                  borderRadius: BorderRadius.vertical(top: AetherRadius.lg),
                ),
                child: Row(
                  children: [
                    Icon(Icons.route_rounded, size: 19, color: accent),
                    const SizedBox(width: AetherSpace.sm),
                    Text('Tramo libre',
                        style: TextStyle(
                            fontFamily: 'Marcellus', fontSize: 17, color: accent.withValues(alpha: 0.95))),
                    const Spacer(),
                    Text('Narra la IA, dentro de tus límites', style: EditorType.meta),
                  ],
                ),
              ),
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(AetherSpace.lg), child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CorridorPageChrome extends StatelessWidget {
  const _CorridorPageChrome({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1210),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111A18),
        iconTheme: IconThemeData(color: accent),
        title: Text('Tramo libre',
            style: TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: accent.withValues(alpha: 0.95))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AetherSpace.lg, AetherSpace.lg, AetherSpace.lg, AetherSpace.huge),
        child: child,
      ),
    );
  }
}

class _CorridorForm extends StatefulWidget {
  const _CorridorForm({
    required this.initialTitle,
    required this.initialNode,
    required this.nodeTitles,
    required this.worldAttributeKeys,
  });

  final String initialTitle;
  final BoundedCorridorNode initialNode;
  final Map<String, String> nodeTitles;
  final List<String> worldAttributeKeys;

  @override
  State<_CorridorForm> createState() => _CorridorFormState();
}

class _CorridorFormState extends State<_CorridorForm> {
  late final _titleController = TextEditingController(text: widget.initialTitle);
  late final _goalController = TextEditingController(text: widget.initialNode.goal);
  late int _turnBudget = widget.initialNode.turnBudget;
  late String? _fallbackExit =
      widget.initialNode.fallbackExitNodeId.isEmpty ? null : widget.initialNode.fallbackExitNodeId;
  late List<String> _allowedLocations = widget.initialNode.allowedLocations;
  late List<String> _allowedNpcs = widget.initialNode.allowedNpcs;
  late List<String> _allowedObstacles = widget.initialNode.allowedObstacles;
  late List<String> _forbiddenReveals = widget.initialNode.forbiddenReveals;
  late List<StoryChoice> _choices = widget.initialNode.choices;

  @override
  void dispose() {
    _titleController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _addChoice() async {
    final choice = await ChoiceEditorScreen.open(
      context,
      initial: null,
      nodeTitles: widget.nodeTitles,
      worldAttributeKeys: widget.worldAttributeKeys,
      accent: EditorNodeColors.boundedCorridor,
    );
    if (choice != null) setState(() => _choices = [..._choices, choice]);
  }

  Future<void> _editChoiceAt(int index) async {
    final choice = await ChoiceEditorScreen.open(
      context,
      initial: _choices[index],
      nodeTitles: widget.nodeTitles,
      worldAttributeKeys: widget.worldAttributeKeys,
      accent: EditorNodeColors.boundedCorridor,
    );
    if (choice != null) {
      setState(() {
        final updated = [..._choices];
        updated[index] = choice;
        _choices = updated;
      });
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    final goal = _goalController.text.trim();
    if (title.isEmpty || goal.isEmpty || _fallbackExit == null) return;
    Navigator.of(context).pop((
      title: title,
      node: BoundedCorridorNode(
        id: widget.initialNode.id,
        goal: goal,
        turnBudget: _turnBudget,
        fallbackExitNodeId: _fallbackExit!,
        allowedLocations: _allowedLocations,
        allowedNpcs: _allowedNpcs,
        allowedObstacles: _allowedObstacles,
        forbiddenReveals: _forbiddenReveals,
        choices: _choices,
        codexReveals: widget.initialNode.codexReveals,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const accent = EditorNodeColors.boundedCorridor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cómo se llama en tu mapa', style: EditorType.overline),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          style: const TextStyle(fontFamily: 'Marcellus', fontSize: 18, color: Color(0xFFBFE5DC)),
          decoration: _decoration(),
        ),
        const SizedBox(height: AetherSpace.lg),
        Text('Qué tiene que conseguir el jugador aquí', style: EditorType.overline),
        const SizedBox(height: 8),
        TextField(
          controller: _goalController,
          maxLines: null,
          minLines: 2,
          style: AetherType.body.copyWith(fontSize: 13.5),
          decoration: _decoration(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Es lo único que la IA puede perseguir aquí.', style: EditorType.hint),
        ),
        const SizedBox(height: AetherSpace.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COMO MUCHO', style: EditorType.overline),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _turnBudget = (_turnBudget - 1).clamp(1, 20)),
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: accent),
                      ),
                      Text('$_turnBudget',
                          style: const TextStyle(fontFamily: 'Marcellus', fontSize: 26, color: accent)),
                      IconButton(
                        onPressed: () => setState(() => _turnBudget = (_turnBudget + 1).clamp(1, 20)),
                        icon: const Icon(Icons.add_circle_outline_rounded, color: accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: NodeTargetDropdown(
                label: 'SI SE LE ACABAN, SALE A',
                value: _fallbackExit,
                nodeTitles: widget.nodeTitles,
                onChanged: (v) => setState(() => _fallbackExit = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: AetherSpace.lg),
        Text('Con qué puede jugar la IA', style: EditorType.overline),
        const SizedBox(height: AetherSpace.sm),
        _GuardrailGroup(
          icon: Icons.place_rounded,
          label: 'Lugares',
          values: _allowedLocations,
          onChanged: (v) => setState(() => _allowedLocations = v),
        ),
        const SizedBox(height: AetherSpace.sm),
        _GuardrailGroup(
          icon: Icons.group_rounded,
          label: 'Gente',
          values: _allowedNpcs,
          onChanged: (v) => setState(() => _allowedNpcs = v),
        ),
        const SizedBox(height: AetherSpace.sm),
        _GuardrailGroup(
          icon: Icons.report_problem_rounded,
          label: 'Problemas que puede poner',
          values: _allowedObstacles,
          onChanged: (v) => setState(() => _allowedObstacles = v),
        ),
        const SizedBox(height: AetherSpace.lg),
        Container(
          padding: const EdgeInsets.all(AetherSpace.md),
          decoration: BoxDecoration(
            color: AetherColors.failure.withValues(alpha: 0.05),
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: AetherColors.failure.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.block_rounded, size: 17, color: AetherColors.failure),
                  const SizedBox(width: AetherSpace.sm),
                  Text('Lo que no puede contar todavía', style: EditorType.label),
                ],
              ),
              const SizedBox(height: AetherSpace.sm),
              ChipListField(
                values: _forbiddenReveals,
                accent: AetherColors.failure,
                onChanged: (v) => setState(() => _forbiddenReveals = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AetherSpace.lg),
        Row(
          children: [
            Expanded(
              child: Text('Salidas que el jugador puede tomar antes de gastar los turnos',
                  style: EditorType.overline),
            ),
            InkWell(
              onTap: _addChoice,
              child: const Icon(Icons.add_circle_outline_rounded, size: 18, color: accent),
            ),
          ],
        ),
        const SizedBox(height: AetherSpace.sm),
        for (final (i, choice) in _choices.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _ChoiceListItem(
              choice: choice,
              targetTitle: widget.nodeTitles[choice.targetNodeId] ?? choice.targetNodeId,
              onTap: () => _editChoiceAt(i),
              onRemove: () => setState(() => _choices = [..._choices]..removeAt(i)),
            ),
          ),
        const SizedBox(height: AetherSpace.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar', style: EditorType.button.copyWith(color: AetherColors.parchmentDim)),
            ),
            const SizedBox(width: AetherSpace.sm),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: const Color(0xFF0B1210),
                shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
              ),
              child: Text('Guardar tramo',
                  style: EditorType.button.copyWith(color: const Color(0xFF0B1210))),
            ),
          ],
        ),
      ],
    );
  }
}

InputDecoration _decoration() => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm + 3),
      filled: true,
      fillColor: const Color(0xFF111A18),
      enabledBorder: OutlineInputBorder(
        borderRadius: AetherRadius.allMd,
        borderSide: BorderSide(color: EditorNodeColors.boundedCorridor.withValues(alpha: 0.24)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AetherRadius.allMd,
        borderSide: const BorderSide(color: EditorNodeColors.boundedCorridor),
      ),
    );

class _GuardrailGroup extends StatelessWidget {
  const _GuardrailGroup({
    required this.icon,
    required this.label,
    required this.values,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.sm + 3),
      decoration: BoxDecoration(
        color: const Color(0xFF111A18),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: EditorNodeColors.boundedCorridor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: EditorNodeColors.boundedCorridor),
              const SizedBox(width: AetherSpace.sm),
              Text(label, style: EditorType.label.copyWith(color: AetherColors.parchmentDim, fontSize: 11)),
            ],
          ),
          const SizedBox(height: AetherSpace.sm),
          ChipListField(
            values: values,
            accent: EditorNodeColors.boundedCorridor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ChoiceListItem extends StatelessWidget {
  const _ChoiceListItem({
    required this.choice,
    required this.targetTitle,
    required this.onTap,
    required this.onRemove,
  });

  final StoryChoice choice;
  final String targetTitle;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm + 2),
        decoration: BoxDecoration(
          color: const Color(0xFF111A18),
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: EditorNodeColors.boundedCorridor.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(choice.label,
                  style: AetherType.body.copyWith(fontSize: 12.5, color: const Color(0xFFDCEBE7))),
            ),
            Icon(Icons.arrow_forward_rounded, size: 14, color: AetherColors.parchmentFaint),
            const SizedBox(width: 6),
            Text(targetTitle, style: EditorType.pill),
            const SizedBox(width: AetherSpace.sm),
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
