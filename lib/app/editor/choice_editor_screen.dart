import 'package:flutter/material.dart';

import '../../core/authoring/campaign_graph_edits.dart';
import '../../core/engine/state_delta.dart';
import '../../core/narrative/gate.dart';
import '../../core/narrative/story_choice.dart';
import '../design/breakpoints.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'design/editor_tokens.dart';
import 'widgets/check_editor.dart';
import 'widgets/gate_editor.dart';
import 'widgets/node_target_dropdown.dart';
import 'widgets/state_delta_editor.dart';

/// Editing surface for one [StoryChoice] — the label, its gate, an optional
/// confirmation, an optional check, and the "sale bien / sale redondo / sale
/// mal" outcome bands (V2 design prototype §9b desktop / §9e mobile). Also
/// doubles as `HubActivity`'s editor via [openForActivity] — same shape
/// minus a target node (an activity never advances the graph, campaign-bible
/// §9.1), so the target field simply doesn't render.
class ChoiceEditorScreen {
  const ChoiceEditorScreen._();

  static Future<StoryChoice?> open(
    BuildContext context, {
    required StoryChoice? initial,
    required Map<String, String> nodeTitles,
    required List<String> worldAttributeKeys,
    required Color accent,
  }) {
    return _openForm<StoryChoice>(
      context,
      title: 'Una cosa que puede hacer el jugador',
      accent: accent,
      builder: (onChanged) => _ChoiceForm(
        initial: initial,
        nodeTitles: nodeTitles,
        worldAttributeKeys: worldAttributeKeys,
        requireTarget: true,
        onChanged: onChanged,
      ),
    );
  }

  /// Same form, without a target-node field — for a [HubActivity], which
  /// never advances the graph. Converts through [StoryChoice] internally
  /// (identical shape minus `targetNodeId`/`id`) purely to reuse this form;
  /// the caller converts the result into a real `HubActivity`.
  static Future<StoryChoice?> openForActivity(
    BuildContext context, {
    required StoryChoice? initialAsChoice,
    required List<String> worldAttributeKeys,
    required Color accent,
    required bool initialRepeatable,
    required ValueChanged<bool> onRepeatableChanged,
  }) {
    return _openForm<StoryChoice>(
      context,
      title: 'Una cosa que puede hacer en cualquier orden',
      accent: accent,
      builder: (onChanged) => _ChoiceForm(
        initial: initialAsChoice,
        nodeTitles: const {},
        worldAttributeKeys: worldAttributeKeys,
        requireTarget: false,
        repeatable: initialRepeatable,
        onRepeatableChanged: onRepeatableChanged,
        onChanged: onChanged,
      ),
    );
  }

  static Future<T?> _openForm<T>(
    BuildContext context, {
    required String title,
    required Color accent,
    required Widget Function(ValueChanged<T?> onChanged) builder,
  }) {
    final desktop = MediaQuery.sizeOf(context).width >= AetherBreakpoints.desktop;
    if (desktop) {
      return showDialog<T>(
        context: context,
        builder: (_) => _DialogChrome(title: title, accent: accent, builder: builder),
      );
    }
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => _PageChrome(title: title, accent: accent, builder: builder)),
    );
  }
}

class _DialogChrome<T> extends StatefulWidget {
  const _DialogChrome({required this.title, required this.accent, required this.builder});

  final String title;
  final Color accent;
  final Widget Function(ValueChanged<T?> onChanged) builder;

  @override
  State<_DialogChrome<T>> createState() => _DialogChromeState<T>();
}

class _DialogChromeState<T> extends State<_DialogChrome<T>> {
  T? _current;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AetherSpace.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 800),
        child: Container(
          decoration: BoxDecoration(
            color: AetherColors.ink,
            borderRadius: AetherRadius.allLg,
            border: Border.all(color: widget.accent.withValues(alpha: 0.28)),
          ),
          child: Column(
            children: [
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg),
                decoration: BoxDecoration(
                  color: AetherColors.surface,
                  borderRadius: const BorderRadius.vertical(top: AetherRadius.lg),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 19, color: widget.accent),
                    const SizedBox(width: AetherSpace.sm),
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(
                              fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close_rounded, size: 19, color: AetherColors.parchmentFaint),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AetherSpace.lg),
                  child: widget.builder((value) => setState(() => _current = value)),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AetherSpace.lg),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AetherColors.hairline)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Descartar',
                          style: EditorType.button.copyWith(color: AetherColors.parchmentDim)),
                    ),
                    const SizedBox(width: AetherSpace.sm),
                    FilledButton(
                      onPressed: _current == null ? null : () => Navigator.of(context).pop(_current),
                      style: FilledButton.styleFrom(
                        backgroundColor: AetherColors.goldBright,
                        foregroundColor: AetherColors.void_,
                        disabledBackgroundColor: AetherColors.surfaceRaised,
                        shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
                      ),
                      child: Text('Guardar', style: EditorType.button.copyWith(color: AetherColors.void_)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageChrome<T> extends StatefulWidget {
  const _PageChrome({required this.title, required this.accent, required this.builder});

  final String title;
  final Color accent;
  final Widget Function(ValueChanged<T?> onChanged) builder;

  @override
  State<_PageChrome<T>> createState() => _PageChromeState<T>();
}

class _PageChromeState<T> extends State<_PageChrome<T>> {
  T? _current;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AetherColors.void_,
      appBar: AppBar(
        backgroundColor: AetherColors.ink,
        iconTheme: const IconThemeData(color: AetherColors.goldSoft),
        title: Text(widget.title,
            style: const TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: AetherColors.goldBright)),
        actions: [
          TextButton(
            onPressed: _current == null ? null : () => Navigator.of(context).pop(_current),
            child: Text('Guardar',
                style: EditorType.button.copyWith(
                    color: _current == null ? AetherColors.parchmentFaint : AetherColors.goldBright)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AetherSpace.lg, AetherSpace.lg, AetherSpace.lg, AetherSpace.huge),
        child: widget.builder((value) => setState(() => _current = value)),
      ),
    );
  }
}

class _ChoiceForm extends StatefulWidget {
  const _ChoiceForm({
    required this.initial,
    required this.nodeTitles,
    required this.worldAttributeKeys,
    required this.requireTarget,
    required this.onChanged,
    this.repeatable,
    this.onRepeatableChanged,
  });

  final StoryChoice? initial;
  final Map<String, String> nodeTitles;
  final List<String> worldAttributeKeys;
  final bool requireTarget;
  final ValueChanged<StoryChoice?> onChanged;
  final bool? repeatable;
  final ValueChanged<bool>? onRepeatableChanged;

  @override
  State<_ChoiceForm> createState() => _ChoiceFormState();
}

class _ChoiceFormState extends State<_ChoiceForm> {
  late final _labelController = TextEditingController(text: widget.initial?.label ?? '');
  late List<Gate> _gateConditions =
      CampaignGraphEdits.flattenGate(widget.initial?.gate ?? const AlwaysGate());
  late bool _requiresConfirmation = widget.initial?.requiresConfirmation ?? false;
  late final _confirmationController =
      TextEditingController(text: widget.initial?.confirmationText ?? '');

  late bool _hasCheck = widget.initial?.checkAttribute != null;
  late String? _checkAttribute = widget.initial?.checkAttribute;
  late int? _checkDifficulty = widget.initial?.checkDifficulty;

  late String? _baseTarget = widget.initial?.targetNodeId;
  late final _baseTextController = TextEditingController(text: widget.initial?.resultText ?? '');
  late List<StateDelta> _baseEffects = widget.initial?.effects ?? const [];

  late String? _successTarget = widget.initial?.onSuccess?.targetNodeId ?? widget.initial?.targetNodeId;
  late final _successTextController =
      TextEditingController(text: widget.initial?.onSuccess?.resultText ?? '');
  late List<StateDelta> _successEffects = widget.initial?.onSuccess?.effects ?? const [];

  late final _criticalTextController =
      TextEditingController(text: widget.initial?.onCriticalSuccess?.resultText ?? '');

  late String? _failureTarget = widget.initial?.onFailure?.targetNodeId ?? widget.initial?.targetNodeId;
  late final _failureTextController =
      TextEditingController(text: widget.initial?.onFailure?.resultText ?? '');
  late List<StateDelta> _failureEffects = widget.initial?.onFailure?.effects ?? const [];

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _labelController,
      _confirmationController,
      _baseTextController,
      _successTextController,
      _criticalTextController,
      _failureTextController,
    ]) {
      controller.addListener(_notify);
    }
    // Deferred, not called synchronously here: this initState runs while
    // the parent chrome (_DialogChromeState/_PageChromeState) is still
    // inside its own build() — calling widget.onChanged (which setStates
    // that ancestor) synchronously at this point would hit "setState()
    // called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notify();
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _confirmationController.dispose();
    _baseTextController.dispose();
    _successTextController.dispose();
    _criticalTextController.dispose();
    _failureTextController.dispose();
    super.dispose();
  }

  void _notify() {
    final label = _labelController.text.trim();
    if (label.isEmpty) return widget.onChanged(null);
    final target = _hasCheck ? _successTarget : _baseTarget;
    if (widget.requireTarget && target == null) return widget.onChanged(null);

    final gate = CampaignGraphEdits.buildGate(_gateConditions);
    final critical = _criticalTextController.text.trim();

    widget.onChanged(StoryChoice(
      label: label,
      targetNodeId: target ?? '',
      gate: gate,
      effects: _hasCheck ? const [] : _baseEffects,
      resultText: _hasCheck || _baseTextController.text.trim().isEmpty
          ? null
          : _baseTextController.text.trim(),
      checkAttribute: _hasCheck ? _checkAttribute : null,
      checkDifficulty: _hasCheck ? _checkDifficulty : null,
      onSuccess: _hasCheck
          ? ChoiceOutcome(
              targetNodeId: _successTarget,
              effects: _successEffects,
              resultText:
                  _successTextController.text.trim().isEmpty ? null : _successTextController.text.trim(),
            )
          : null,
      onCriticalSuccess: _hasCheck && critical.isNotEmpty
          ? ChoiceOutcome(resultText: critical)
          : null,
      onFailure: _hasCheck
          ? ChoiceOutcome(
              targetNodeId: _failureTarget,
              effects: _failureEffects,
              resultText:
                  _failureTextController.text.trim().isEmpty ? null : _failureTextController.text.trim(),
            )
          : null,
      requiresConfirmation: _requiresConfirmation,
      confirmationText:
          _requiresConfirmation && _confirmationController.text.trim().isNotEmpty
              ? _confirmationController.text.trim()
              : null,
      advantageWhen: widget.initial?.advantageWhen,
      disadvantageWhen: widget.initial?.disadvantageWhen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Qué lee el jugador en el botón', style: EditorType.overline),
        const SizedBox(height: 8),
        TextField(
          controller: _labelController,
          style: AetherType.body.copyWith(fontSize: 15),
          decoration: _fieldDecoration(),
        ),
        const SizedBox(height: AetherSpace.lg),
        Text('Sólo aparece si…', style: EditorType.overline),
        const SizedBox(height: 8),
        GateEditor(
          conditions: _gateConditions,
          worldAttributeKeys: widget.worldAttributeKeys,
          onChanged: (v) => setState(() {
            _gateConditions = v;
            _notify();
          }),
        ),
        const SizedBox(height: AetherSpace.lg),
        _ConfirmationSection(
          enabled: _requiresConfirmation,
          controller: _confirmationController,
          onToggle: (v) => setState(() {
            _requiresConfirmation = v;
            _notify();
          }),
        ),
        const SizedBox(height: AetherSpace.lg),
        CheckEditor(
          attribute: _checkAttribute,
          difficulty: _checkDifficulty,
          worldAttributeKeys: widget.worldAttributeKeys,
          onChanged: (attribute, difficulty) => setState(() {
            _hasCheck = attribute != null;
            _checkAttribute = attribute;
            _checkDifficulty = difficulty;
            _notify();
          }),
        ),
        if (widget.repeatable != null) ...[
          const SizedBox(height: AetherSpace.lg),
          Row(
            children: [
              Expanded(child: Text('Se puede repetir', style: AetherType.body.copyWith(fontSize: 13))),
              Switch(
                value: widget.repeatable!,
                activeThumbColor: AetherColors.goldBright,
                onChanged: widget.onRepeatableChanged,
              ),
            ],
          ),
        ],
        const SizedBox(height: AetherSpace.lg),
        Text('Y entonces qué pasa', style: EditorType.overline),
        const SizedBox(height: AetherSpace.sm),
        if (!_hasCheck)
          _OutcomeBand(
            label: 'RESULTADO',
            color: AetherColors.parchmentDim,
            textController: _baseTextController,
            effects: _baseEffects,
            onEffectsChanged: (v) => setState(() {
              _baseEffects = v;
              _notify();
            }),
            target: widget.requireTarget ? _baseTarget : null,
            nodeTitles: widget.nodeTitles,
            onTargetChanged: widget.requireTarget
                ? (v) => setState(() {
                      _baseTarget = v;
                      _notify();
                    })
                : null,
          )
        else ...[
          _OutcomeBand(
            label: 'SALE BIEN',
            sublabel: 'total suficiente',
            color: AetherColors.success,
            textController: _successTextController,
            effects: _successEffects,
            onEffectsChanged: (v) => setState(() {
              _successEffects = v;
              _notify();
            }),
            target: widget.requireTarget ? _successTarget : null,
            nodeTitles: widget.nodeTitles,
            onTargetChanged: widget.requireTarget
                ? (v) => setState(() {
                      _successTarget = v;
                      _notify();
                    })
                : null,
          ),
          const SizedBox(height: AetherSpace.sm),
          _CriticalBand(controller: _criticalTextController),
          const SizedBox(height: AetherSpace.sm),
          _OutcomeBand(
            label: 'SALE MAL',
            sublabel: 'total insuficiente',
            color: AetherColors.failure,
            textController: _failureTextController,
            effects: _failureEffects,
            onEffectsChanged: (v) => setState(() {
              _failureEffects = v;
              _notify();
            }),
            target: widget.requireTarget ? _failureTarget : null,
            nodeTitles: widget.nodeTitles,
            onTargetChanged: widget.requireTarget
                ? (v) => setState(() {
                      _failureTarget = v;
                      _notify();
                    })
                : null,
          ),
        ],
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
        borderSide: const BorderSide(color: AetherColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AetherRadius.allMd,
        borderSide: const BorderSide(color: AetherColors.gold),
      ),
    );

class _ConfirmationSection extends StatelessWidget {
  const _ConfirmationSection({required this.enabled, required this.controller, required this.onToggle});

  final bool enabled;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.sm + 2),
      decoration: BoxDecoration(
        color: enabled ? AetherColors.failure.withValues(alpha: 0.05) : AetherColors.surface,
        borderRadius: AetherRadius.allMd,
        border: Border.all(
            color: enabled ? AetherColors.failure.withValues(alpha: 0.3) : AetherColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.priority_high_rounded,
                  size: 17, color: enabled ? AetherColors.failure : AetherColors.parchmentFaint),
              const SizedBox(width: AetherSpace.sm),
              Expanded(
                child: Text('Pedir confirmación antes de hacerlo',
                    style: AetherType.body.copyWith(fontSize: 12.5)),
              ),
              Switch(value: enabled, onChanged: onToggle, activeThumbColor: AetherColors.failure),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: AetherSpace.sm),
            TextField(
              controller: controller,
              style: AetherType.body.copyWith(fontSize: 12.5, fontStyle: FontStyle.italic),
              decoration: _fieldDecoration().copyWith(hintText: 'Texto de la confirmación'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeBand extends StatelessWidget {
  const _OutcomeBand({
    required this.label,
    required this.color,
    required this.textController,
    required this.effects,
    required this.onEffectsChanged,
    required this.nodeTitles,
    this.sublabel,
    this.target,
    this.onTargetChanged,
  });

  final String label;
  final String? sublabel;
  final Color color;
  final TextEditingController textController;
  final List<StateDelta> effects;
  final ValueChanged<List<StateDelta>> onEffectsChanged;
  final Map<String, String> nodeTitles;
  final String? target;
  final ValueChanged<String?>? onTargetChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: AetherRadius.allPill,
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(label,
                    style: EditorType.kicker.copyWith(color: color, letterSpacing: 1.2)),
              ),
              if (sublabel != null) ...[
                const SizedBox(width: AetherSpace.sm),
                Text(sublabel!, style: EditorType.meta),
              ],
            ],
          ),
          const SizedBox(height: AetherSpace.sm),
          TextField(
            controller: textController,
            maxLines: null,
            minLines: 2,
            style: AetherType.body.copyWith(fontSize: 13),
            decoration: _fieldDecoration().copyWith(hintText: 'Qué narra'),
          ),
          if (onTargetChanged != null) ...[
            const SizedBox(height: AetherSpace.sm),
            NodeTargetDropdown(value: target, nodeTitles: nodeTitles, onChanged: onTargetChanged!),
          ],
          const SizedBox(height: AetherSpace.sm),
          StateDeltaEditor(effects: effects, onChanged: onEffectsChanged),
        ],
      ),
    );
  }
}

class _CriticalBand extends StatelessWidget {
  const _CriticalBand({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.md),
      decoration: BoxDecoration(
        color: AetherColors.goldBright.withValues(alpha: 0.04),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: AetherColors.goldBright.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AetherColors.goldBright.withValues(alpha: 0.14),
                  borderRadius: AetherRadius.allPill,
                  border: Border.all(color: AetherColors.goldBright.withValues(alpha: 0.5)),
                ),
                child: Text('SALE REDONDO',
                    style: EditorType.kicker.copyWith(color: AetherColors.goldBright, letterSpacing: 1.2)),
              ),
              const SizedBox(width: AetherSpace.sm),
              Text('saca 20 natural', style: EditorType.meta),
              const Spacer(),
              Text('si no lo escribís, usa "sale bien"',
                  style: EditorType.meta.copyWith(fontSize: 9.5)),
            ],
          ),
          const SizedBox(height: AetherSpace.sm),
          TextField(
            controller: controller,
            maxLines: null,
            minLines: 1,
            style: AetherType.body.copyWith(fontSize: 13),
            decoration: _fieldDecoration().copyWith(hintText: 'Opcional'),
          ),
        ],
      ),
    );
  }
}
