import 'package:flutter/material.dart';

import '../../../core/authoring/campaign_summaries.dart';
import '../../../core/engine/state_delta.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../design/editor_tokens.dart';

const _deltaTypes = [
  StateDeltaType.flag,
  StateDeltaType.exp,
  StateDeltaType.resource,
  StateDeltaType.meter,
  StateDeltaType.relationship,
  StateDeltaType.listAdd,
  StateDeltaType.listRemove,
  StateDeltaType.varSet,
];

String _typeLabel(StateDeltaType type) => switch (type) {
      StateDeltaType.flag => 'Marcar una bandera',
      StateDeltaType.exp => 'Dar experiencia',
      StateDeltaType.resource => 'Cambiar un recurso',
      StateDeltaType.meter => 'Cambiar un medidor',
      StateDeltaType.relationship => 'Cambiar una relación',
      StateDeltaType.listAdd => 'Añadir a una lista',
      StateDeltaType.listRemove => 'Quitar de una lista',
      StateDeltaType.varSet => 'Fijar una variable',
      _ => type.name,
    };

/// The consequence chips under an outcome band (V2 design prototype §9b:
/// "+30 experiencia", "-El anciano te quiere 2 menos", "🚩 Queda marcado…").
class StateDeltaEditor extends StatelessWidget {
  const StateDeltaEditor({super.key, required this.effects, required this.onChanged});

  final List<StateDelta> effects;
  final ValueChanged<List<StateDelta>> onChanged;

  Future<void> _add(BuildContext context) async {
    final delta = await showDialog<StateDelta>(
      context: context,
      builder: (_) => const _StateDeltaDialog(),
    );
    if (delta != null) onChanged([...effects, delta]);
  }

  void _removeAt(int index) => onChanged([...effects]..removeAt(index));

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, delta) in effects.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AetherColors.surface,
              borderRadius: AetherRadius.allSm,
              border: Border.all(color: AetherColors.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(CampaignSummaries.stateDelta(delta), style: EditorType.pill),
                const SizedBox(width: 5),
                InkWell(
                  onTap: () => _removeAt(i),
                  child: const Icon(Icons.close_rounded, size: 12, color: AetherColors.parchmentFaint),
                ),
              ],
            ),
          ),
        InkWell(
          onTap: () => _add(context),
          borderRadius: AetherRadius.allSm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: AetherRadius.allSm,
              border: Border.all(color: AetherColors.hairlineStrong),
            ),
            child: Text('+ añadir consecuencia',
                style: EditorType.pill.copyWith(color: AetherColors.parchmentFaint)),
          ),
        ),
      ],
    );
  }
}

class _StateDeltaDialog extends StatefulWidget {
  const _StateDeltaDialog();

  @override
  State<_StateDeltaDialog> createState() => _StateDeltaDialogState();
}

class _StateDeltaDialogState extends State<_StateDeltaDialog> {
  StateDeltaType _type = StateDeltaType.exp;
  final _keyController = TextEditingController(text: 'exp');
  final _valueController = TextEditingController(text: '10');
  final _stringValueController = TextEditingController();
  bool _boolValue = true;

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _stringValueController.dispose();
    super.dispose();
  }

  bool get _usesNumericValue => switch (_type) {
        StateDeltaType.exp ||
        StateDeltaType.resource ||
        StateDeltaType.meter ||
        StateDeltaType.relationship =>
          true,
        _ => false,
      };

  bool get _usesKey => _type != StateDeltaType.exp;

  StateDelta? _build() {
    final key = _usesKey ? _keyController.text.trim() : 'exp';
    if (_usesKey && key.isEmpty) return null;
    final Object value = switch (_type) {
      StateDeltaType.flag => _boolValue,
      StateDeltaType.varSet || StateDeltaType.listAdd || StateDeltaType.listRemove =>
        _stringValueController.text.trim(),
      _ => int.tryParse(_valueController.text.trim()) ?? 0,
    };
    if (value is String && value.isEmpty) return null;
    return StateDelta(type: _type, key: key, value: value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AetherColors.surface,
      title: Text('Nueva consecuencia', style: AetherType.title.copyWith(fontSize: 16)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Qué hace', style: EditorType.overline),
            const SizedBox(height: 6),
            DropdownButton<StateDeltaType>(
              value: _type,
              isExpanded: true,
              dropdownColor: AetherColors.surface,
              items: [
                for (final type in _deltaTypes)
                  DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: AetherSpace.md),
            if (_usesKey) ...[
              Text(
                _type == StateDeltaType.relationship ? 'NPC' : 'Clave',
                style: EditorType.overline,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _keyController,
                style: AetherType.body.copyWith(fontSize: 13),
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: AetherSpace.md),
            ],
            if (_usesNumericValue) ...[
              Text('Cuánto (puede ser negativo)', style: EditorType.overline),
              const SizedBox(height: 6),
              TextField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                style: AetherType.body.copyWith(fontSize: 13),
                decoration: const InputDecoration(isDense: true),
              ),
            ] else if (_type == StateDeltaType.flag) ...[
              _BoolRow(value: _boolValue, onChanged: (v) => setState(() => _boolValue = v)),
            ] else ...[
              Text('Valor', style: EditorType.overline),
              const SizedBox(height: 6),
              TextField(
                controller: _stringValueController,
                style: AetherType.body.copyWith(fontSize: 13),
                decoration: const InputDecoration(isDense: true),
              ),
            ],
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
            final delta = _build();
            if (delta != null) Navigator.of(context).pop(delta);
          },
          child: Text('Añadir', style: EditorType.button.copyWith(color: AetherColors.goldBright)),
        ),
      ],
    );
  }
}

class _BoolRow extends StatelessWidget {
  const _BoolRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('Activarla', style: AetherType.body.copyWith(fontSize: 12.5))),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AetherColors.goldBright),
      ],
    );
  }
}
