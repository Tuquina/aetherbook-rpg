import 'package:flutter/material.dart';

import '../../core/authoring/campaign_graph_edits.dart';
import '../../core/authoring/campaign_summaries.dart';
import '../../core/narrative/ending.dart';
import '../../core/narrative/gate.dart';
import '../design/breakpoints.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'design/editor_tokens.dart';
import 'widgets/chip_list_field.dart';
import 'widgets/gate_editor.dart';

const _resolutionAccent = EditorNodeColors.resolution;

/// Editing surface for one [Ending] inside a `ResolutionNode` (V2 design
/// prototype §9c) — the hard requirement that gates it, the soft
/// requirements that only ease its resolving check, and the resulting
/// difficulty ladder. The ladder itself isn't author-editable as a raw
/// number map (`Ending.difficultyBySoftRequirementsMet`) — it's derived from
/// [baseDifficulty] by stepping down 3 per soft requirement met (floored at
/// 9), the exact curve the mockup's bar chart shows, so the author only ever
/// picks one number.
class EndingEditorScreen {
  const EndingEditorScreen._();

  static Future<Ending?> open(
    BuildContext context, {
    required Ending? initial,
    required int indexLabel,
    required int totalCount,
    required String resolutionTitle,
    required List<String> worldAttributeKeys,
  }) {
    final desktop = MediaQuery.sizeOf(context).width >= AetherBreakpoints.desktop;
    final content = _EndingForm(initial: initial, worldAttributeKeys: worldAttributeKeys);
    if (desktop) {
      return showDialog<Ending>(
        context: context,
        builder: (_) => _EndingDialogChrome(
          indexLabel: indexLabel,
          totalCount: totalCount,
          resolutionTitle: resolutionTitle,
          child: content,
        ),
      );
    }
    return Navigator.of(context).push<Ending>(
      MaterialPageRoute(
        builder: (_) => _EndingPageChrome(
          indexLabel: indexLabel,
          totalCount: totalCount,
          resolutionTitle: resolutionTitle,
          child: content,
        ),
      ),
    );
  }
}

class _EndingDialogChrome extends StatelessWidget {
  const _EndingDialogChrome({
    required this.indexLabel,
    required this.totalCount,
    required this.resolutionTitle,
    required this.child,
  });

  final int indexLabel;
  final int totalCount;
  final String resolutionTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AetherSpace.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Container(
          decoration: BoxDecoration(
            color: AetherColors.ink,
            borderRadius: AetherRadius.allLg,
            border: Border.all(color: _resolutionAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _resolutionAccent.withValues(alpha: 0.12),
                    AetherColors.surface,
                  ]),
                  borderRadius: const BorderRadius.vertical(top: AetherRadius.lg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded, size: 19, color: _resolutionAccent),
                    const SizedBox(width: AetherSpace.sm),
                    const Text('Un final posible',
                        style: TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright)),
                    const Spacer(),
                    Text('$indexLabel de $totalCount en «$resolutionTitle»', style: EditorType.meta),
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

class _EndingPageChrome extends StatelessWidget {
  const _EndingPageChrome({
    required this.indexLabel,
    required this.totalCount,
    required this.resolutionTitle,
    required this.child,
  });

  final int indexLabel;
  final int totalCount;
  final String resolutionTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.void_,
      appBar: AppBar(
        backgroundColor: AetherColors.ink,
        iconTheme: const IconThemeData(color: AetherColors.goldSoft),
        title: const Text('Un final posible',
            style: TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AetherSpace.lg, AetherSpace.lg, AetherSpace.lg, AetherSpace.huge),
        child: child,
      ),
    );
  }
}

class _EndingForm extends StatefulWidget {
  const _EndingForm({required this.initial, required this.worldAttributeKeys});

  final Ending? initial;
  final List<String> worldAttributeKeys;

  @override
  State<_EndingForm> createState() => _EndingFormState();
}

class _EndingFormState extends State<_EndingForm> {
  late final _idController =
      TextEditingController(text: widget.initial?.id ?? 'final_${DateTime.now().millisecondsSinceEpoch}');
  late final _visibleChoiceController = TextEditingController(text: widget.initial?.visibleChoice ?? '');
  late List<Gate> _hardConditions =
      CampaignGraphEdits.flattenGate(widget.initial?.hardRequirement ?? const AlwaysGate());
  late List<Gate> _softRequirements = widget.initial?.softRequirements ?? const [];
  late int _baseDifficulty = widget.initial?.baseDifficulty ?? DifficultyPreset.casiImposible.value;
  late List<String> _successReveals = widget.initial?.successReveals ?? const [];
  late List<String> _costReveals = widget.initial?.costReveals ?? const [];
  late List<String> _failureCostOptions = widget.initial?.failureCostOptions ?? const [];

  @override
  void dispose() {
    _idController.dispose();
    _visibleChoiceController.dispose();
    super.dispose();
  }

  Map<int, int> get _difficultyLadder {
    final n = _softRequirements.length;
    return {for (var met = 0; met <= n; met++) met: (_baseDifficulty - met * 3).clamp(9, 21)};
  }

  void _save() {
    final choice = _visibleChoiceController.text.trim();
    if (choice.isEmpty) return;
    Navigator.of(context).pop(Ending(
      id: _idController.text.trim(),
      visibleChoice: choice,
      hardRequirement: CampaignGraphEdits.buildGate(_hardConditions),
      softRequirements: _softRequirements,
      difficultyBySoftRequirementsMet: _difficultyLadder,
      baseDifficulty: _baseDifficulty,
      successReveals: _successReveals,
      costReveals: _costReveals,
      failureCostOptions: _failureCostOptions,
      onFailureFallbacks: widget.initial?.onFailureFallbacks ?? const [],
      bodyBeats: widget.initial?.bodyBeats ?? const [],
    ));
  }

  Future<void> _addSoftRequirement() async {
    final gate = await showDialog<Gate>(
      context: context,
      builder: (_) => _SoftRequirementPickerDialog(worldAttributeKeys: widget.worldAttributeKeys),
    );
    if (gate != null) setState(() => _softRequirements = [..._softRequirements, gate]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Qué elige el jugador para intentarlo', style: EditorType.overline),
        const SizedBox(height: 8),
        TextField(
          controller: _visibleChoiceController,
          maxLines: null,
          minLines: 2,
          style: AetherType.body.copyWith(fontSize: 14.5),
          decoration: _fieldDecoration(),
        ),
        const SizedBox(height: AetherSpace.lg),
        Container(
          padding: const EdgeInsets.all(AetherSpace.md),
          decoration: BoxDecoration(
            color: AetherColors.failure.withValues(alpha: 0.04),
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: AetherColors.failure.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 17, color: AetherColors.failure),
                  const SizedBox(width: AetherSpace.sm),
                  Text('Sin esto, el final ni se ofrece', style: EditorType.label),
                ],
              ),
              const SizedBox(height: AetherSpace.sm),
              GateEditor(
                conditions: _hardConditions,
                worldAttributeKeys: widget.worldAttributeKeys,
                onChanged: (v) => setState(() => _hardConditions = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AetherSpace.md),
        Container(
          padding: const EdgeInsets.all(AetherSpace.md),
          decoration: BoxDecoration(
            color: AetherColors.success.withValues(alpha: 0.04),
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: AetherColors.success.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_down_rounded, size: 17, color: AetherColors.success),
                  const SizedBox(width: AetherSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Esto no bloquea nada — sólo lo hace más fácil', style: EditorType.label),
                        Text('Cada cosa que el jugador haya cumplido baja la dificultad.',
                            style: EditorType.hint),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AetherSpace.sm),
              for (final (i, gate) in _softRequirements.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 15, color: AetherColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(CampaignSummaries.gate(gate),
                              style: AetherType.body.copyWith(fontSize: 12.5))),
                      InkWell(
                        onTap: () =>
                            setState(() => _softRequirements = [..._softRequirements]..removeAt(i)),
                        child: const Icon(Icons.close_rounded, size: 15, color: AetherColors.parchmentFaint),
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap: _addSoftRequirement,
                child: Text('+ añadir requisito blando',
                    style: EditorType.button.copyWith(color: AetherColors.success, fontSize: 11.5)),
              ),
              const SizedBox(height: AetherSpace.md),
              Text('Dificultad si nadie cumplió nada', style: EditorType.overline),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final preset in DifficultyPreset.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _PresetButton(
                          preset: preset,
                          selected: _baseDifficulty == preset.value,
                          onTap: () => setState(() => _baseDifficulty = preset.value),
                        ),
                      ),
                    ),
                ],
              ),
              if (_softRequirements.isNotEmpty) ...[
                const SizedBox(height: AetherSpace.md),
                _DifficultyLadder(ladder: _difficultyLadder, total: _softRequirements.length),
              ],
            ],
          ),
        ),
        const SizedBox(height: AetherSpace.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RevealBox(
                label: 'Si lo consigue, contar sí o sí',
                color: AetherColors.success,
                values: _successReveals,
                onChanged: (v) => setState(() => _successReveals = v),
              ),
            ),
            const SizedBox(width: AetherSpace.sm),
            Expanded(
              child: _RevealBox(
                label: 'Y lo que cuesta',
                color: AetherColors.failure,
                values: _costReveals,
                onChanged: (v) => setState(() => _costReveals = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: AetherSpace.md),
        Container(
          padding: const EdgeInsets.all(AetherSpace.sm + 3),
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: AetherColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.alt_route_rounded, size: 17, color: AetherColors.parchmentDim),
                  const SizedBox(width: AetherSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Si falla la tirada, el jugador elige qué pierde', style: EditorType.label),
                        Text('Ninguno de estos costos cierra la historia.', style: EditorType.hint),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AetherSpace.sm),
              ChipListField(
                values: _failureCostOptions,
                accent: _resolutionAccent,
                onChanged: (v) => setState(() => _failureCostOptions = v),
              ),
            ],
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
                backgroundColor: AetherColors.goldBright,
                foregroundColor: AetherColors.void_,
                shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
              ),
              child: Text('Guardar final', style: EditorType.button.copyWith(color: AetherColors.void_)),
            ),
          ],
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration() => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm + 3),
      filled: true,
      fillColor: AetherColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: AetherRadius.allMd,
        borderSide: BorderSide(color: _resolutionAccent.withValues(alpha: 0.3)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AetherRadius.allMd,
        borderSide: BorderSide(color: _resolutionAccent),
      ),
    );

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.preset, required this.selected, required this.onTap});

  final DifficultyPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allSm,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AetherColors.success.withValues(alpha: 0.16) : null,
          borderRadius: AetherRadius.allSm,
          border: Border.all(
              color: selected ? AetherColors.success.withValues(alpha: 0.55) : AetherColors.hairline),
        ),
        child: Column(
          children: [
            Text(preset.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Archivo',
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AetherColors.success : AetherColors.parchmentFaint,
                )),
            Text('${preset.value}',
                style: TextStyle(
                    fontFamily: 'Archivo',
                    fontSize: 9,
                    color: selected ? AetherColors.parchmentDim : AetherColors.parchmentFaint)),
          ],
        ),
      ),
    );
  }
}

class _DifficultyLadder extends StatelessWidget {
  const _DifficultyLadder({required this.ladder, required this.total});

  final Map<int, int> ladder;
  final int total;

  @override
  Widget build(BuildContext context) {
    const maxHeight = 60.0;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var met = 0; met <= total; met++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      SizedBox(
                        height: maxHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            height: maxHeight * (ladder[met]! / 21),
                            decoration: BoxDecoration(
                              color: AetherColors.success.withValues(alpha: 0.14 + met * 0.05),
                              border: Border.all(color: AetherColors.success.withValues(alpha: 0.4)),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                            alignment: Alignment.topCenter,
                            padding: const EdgeInsets.only(top: 5),
                            child: Text('${ladder[met]}',
                                style: const TextStyle(
                                    fontFamily: 'Archivo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AetherColors.success)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        met == 0 ? 'ninguna' : (met == total ? 'todas' : '$met de $total'),
                        style: EditorType.hint.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RevealBox extends StatelessWidget {
  const _RevealBox({
    required this.label,
    required this.color,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.sm + 3),
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: EditorType.overline.copyWith(color: color)),
          const SizedBox(height: AetherSpace.sm),
          ChipListField(values: values, accent: color, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SoftRequirementPickerDialog extends StatelessWidget {
  const _SoftRequirementPickerDialog({required this.worldAttributeKeys});

  final List<String> worldAttributeKeys;

  @override
  Widget build(BuildContext context) {
    // Reuses the same atomic-condition builder as the hard requirement's
    // GateEditor — a soft requirement is just one more Gate, added one at a
    // time via the identical "+ añadir condición" flow, so this dialog
    // simply hosts a single-item GateEditor and returns its first (only)
    // built condition once the author adds one.
    final conditions = <Gate>[];
    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AetherColors.surface,
        title: Text('Nuevo requisito blando', style: AetherType.title.copyWith(fontSize: 16)),
        content: SizedBox(
          width: 340,
          child: GateEditor(
            conditions: conditions,
            worldAttributeKeys: worldAttributeKeys,
            onChanged: (v) {
              if (v.isNotEmpty) Navigator.of(context).pop(v.last);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: EditorType.button.copyWith(color: AetherColors.parchmentDim)),
          ),
        ],
      ),
    );
  }
}
