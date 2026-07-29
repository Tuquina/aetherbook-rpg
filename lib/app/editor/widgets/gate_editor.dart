import 'package:flutter/material.dart';

import '../../../core/authoring/campaign_summaries.dart';
import '../../../core/narrative/gate.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../design/editor_tokens.dart';

const _atomicGateTypes = [
  'flag',
  'level',
  'attribute',
  'resource',
  'meter',
  'relationship',
  'var',
  'list',
];

String _typeLabel(String type) => switch (type) {
      'flag' => 'Una bandera de la historia',
      'level' => 'El nivel del personaje',
      'attribute' => 'Un atributo',
      'resource' => 'Un recurso',
      'meter' => 'Un medidor',
      'relationship' => 'Una relación con un NPC',
      'var' => 'Una variable',
      'list' => 'Una lista (p. ej. inventario)',
      _ => type,
    };

/// A flat AND-list of [Gate] conditions (V2 design prototype §9b/§9c/§9g/§9h
/// "Sólo aparece si…") — [conditions] is [CampaignGraphEdits.flattenGate]'s
/// output, [onChanged] receives the updated flat list; the caller rebuilds
/// the real [Gate] via [CampaignGraphEdits.buildGate] before saving. Kept
/// deliberately AND-only (no OR/nested-composite UI) — that covers every
/// condition the mockup shows; an existing OR/nested gate loaded from
/// hand-written content still round-trips (shown read-only, see
/// [CampaignGraphEdits.flattenGate]'s doc comment), just can't be built from
/// scratch here.
class GateEditor extends StatelessWidget {
  const GateEditor({
    super.key,
    required this.conditions,
    required this.onChanged,
    required this.worldAttributeKeys,
  });

  final List<Gate> conditions;
  final ValueChanged<List<Gate>> onChanged;
  final List<String> worldAttributeKeys;

  Future<void> _add(BuildContext context) async {
    final gate = await showDialog<Gate>(
      context: context,
      builder: (_) => _GateConditionDialog(worldAttributeKeys: worldAttributeKeys),
    );
    if (gate != null) onChanged([...conditions, gate]);
  }

  void _removeAt(int index) {
    onChanged([...conditions]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (conditions.isEmpty)
          Text('Siempre aparece.', style: AetherType.caption)
        else
          for (final (i, gate) in conditions.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2, vertical: 7),
                decoration: BoxDecoration(
                  color: AetherColors.surface,
                  borderRadius: AetherRadius.allSm,
                  border: Border.all(color: AetherColors.hairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(CampaignSummaries.gate(gate),
                          style: AetherType.body.copyWith(fontSize: 12.5)),
                    ),
                    InkWell(
                      onTap: () => _removeAt(i),
                      child: const Icon(Icons.close_rounded, size: 15, color: AetherColors.parchmentFaint),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _add(context),
          child: Text('+ añadir condición',
              style: EditorType.button.copyWith(color: AetherColors.goldBright, fontSize: 11.5)),
        ),
      ],
    );
  }
}

class _GateConditionDialog extends StatefulWidget {
  const _GateConditionDialog({required this.worldAttributeKeys});

  final List<String> worldAttributeKeys;

  @override
  State<_GateConditionDialog> createState() => _GateConditionDialogState();
}

class _GateConditionDialogState extends State<_GateConditionDialog> {
  String _type = 'flag';
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  int _numericValue = 1;
  bool _boolValue = true;
  bool _isMax = false;

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Gate? _build() {
    final key = _keyController.text.trim();
    if (key.isEmpty && _type != 'level') return null;
    return switch (_type) {
      'flag' => FlagGate(key, _boolValue),
      'level' => MinLevelGate(_numericValue),
      'attribute' => MinAttributeGate(key, _numericValue),
      'resource' => MinResourceGate(key, _numericValue),
      'meter' => _isMax ? MaxMeterGate(key, _numericValue) : MinMeterGate(key, _numericValue),
      'relationship' =>
        _isMax ? MaxRelationshipGate(key, _numericValue) : MinRelationshipGate(key, _numericValue),
      'var' => VarGate(key, _valueController.text.trim()),
      'list' => ListContainsGate(key, _valueController.text.trim(), _boolValue),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AetherColors.surface,
      title: Text('Nueva condición', style: AetherType.title.copyWith(fontSize: 16)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Qué revisa', style: EditorType.overline),
            const SizedBox(height: 6),
            DropdownButton<String>(
              value: _type,
              isExpanded: true,
              dropdownColor: AetherColors.surface,
              items: [
                for (final type in _atomicGateTypes)
                  DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: AetherSpace.md),
            if (_type != 'level') ...[
              Text(_type == 'attribute' ? 'Cuál' : 'Clave', style: EditorType.overline),
              const SizedBox(height: 6),
              if (_type == 'attribute' && widget.worldAttributeKeys.isNotEmpty)
                DropdownButton<String>(
                  value: widget.worldAttributeKeys.contains(_keyController.text)
                      ? _keyController.text
                      : widget.worldAttributeKeys.first,
                  isExpanded: true,
                  dropdownColor: AetherColors.surface,
                  items: [
                    for (final key in widget.worldAttributeKeys)
                      DropdownMenuItem(value: key, child: Text(key)),
                  ],
                  onChanged: (value) => setState(() => _keyController.text = value!),
                )
              else
                TextField(
                  controller: _keyController,
                  style: AetherType.body.copyWith(fontSize: 13),
                  decoration: const InputDecoration(isDense: true),
                ),
              const SizedBox(height: AetherSpace.md),
            ],
            switch (_type) {
              'flag' => _BoolRow(
                  label: 'Debe estar activa',
                  value: _boolValue,
                  onChanged: (v) => setState(() => _boolValue = v),
                ),
              'var' => _TextRow(label: 'Debe valer', controller: _valueController),
              'list' => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TextRow(label: 'Debe incluir', controller: _valueController),
                    const SizedBox(height: AetherSpace.sm),
                    _BoolRow(
                      label: 'Debe incluirlo (no excluirlo)',
                      value: _boolValue,
                      onChanged: (v) => setState(() => _boolValue = v),
                    ),
                  ],
                ),
              'meter' || 'relationship' => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BoolRow(
                      label: 'Es un techo (como mucho)',
                      value: _isMax,
                      onChanged: (v) => setState(() => _isMax = v),
                    ),
                    const SizedBox(height: AetherSpace.sm),
                    _NumberRow(
                      label: _isMax ? 'Como mucho' : 'Como mínimo',
                      value: _numericValue,
                      onChanged: (v) => setState(() => _numericValue = v),
                    ),
                  ],
                ),
              _ => _NumberRow(
                  label: 'Como mínimo',
                  value: _numericValue,
                  onChanged: (v) => setState(() => _numericValue = v),
                ),
            },
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: EditorType.button.copyWith(color: AetherColors.parchmentDim)),
        ),
        TextButton(
          onPressed: () {
            final gate = _build();
            if (gate != null) Navigator.of(context).pop(gate);
          },
          child: Text('Añadir', style: EditorType.button.copyWith(color: AetherColors.goldBright)),
        ),
      ],
    );
  }
}

class _BoolRow extends StatelessWidget {
  const _BoolRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AetherType.body.copyWith(fontSize: 12.5))),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AetherColors.goldBright),
      ],
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: EditorType.overline),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: AetherType.body.copyWith(fontSize: 13),
          decoration: const InputDecoration(isDense: true),
        ),
      ],
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AetherType.body.copyWith(fontSize: 12.5))),
        IconButton(
          onPressed: () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AetherColors.parchmentFaint),
        ),
        Text('$value', style: AetherType.body.copyWith(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AetherColors.parchmentFaint),
        ),
      ],
    );
  }
}
