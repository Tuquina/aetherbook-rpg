import 'package:flutter/material.dart';

import '../../core/narrative/gate.dart';
import '../../core/narrative/hub_activity.dart';
import '../../core/narrative/story_choice.dart';
import '../../core/narrative/story_node.dart';
import '../design/breakpoints.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'choice_editor_screen.dart';
import 'design/editor_tokens.dart';

typedef HubEditResult = ({String title, StateHubNode node});

/// Editing surface for a [StateHubNode] (V2 design prototype §9h, "Alto en
/// el camino") — its unordered [HubActivity] list and its graph-advancing
/// exits.
class HubEditorScreen {
  const HubEditorScreen._();

  static Future<HubEditResult?> open(
    BuildContext context, {
    required String initialTitle,
    required StateHubNode initialNode,
    required Map<String, String> nodeTitles,
    required List<String> worldAttributeKeys,
  }) {
    const accent = EditorNodeColors.stateHub;
    final desktop = MediaQuery.sizeOf(context).width >= AetherBreakpoints.desktop;
    final content = _HubForm(
      initialTitle: initialTitle,
      initialNode: initialNode,
      nodeTitles: nodeTitles,
      worldAttributeKeys: worldAttributeKeys,
    );
    if (desktop) {
      return showDialog<HubEditResult>(
        context: context,
        builder: (_) => _HubDialogChrome(accent: accent, child: content),
      );
    }
    return Navigator.of(context).push<HubEditResult>(
      MaterialPageRoute(builder: (_) => _HubPageChrome(accent: accent, child: content)),
    );
  }
}

class _HubDialogChrome extends StatelessWidget {
  const _HubDialogChrome({required this.accent, required this.child});

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
            color: const Color(0xFF080B0F),
            borderRadius: AetherRadius.allLg,
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Column(
            children: [
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F151B),
                  borderRadius: BorderRadius.vertical(top: AetherRadius.lg),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 19, color: accent),
                    const SizedBox(width: AetherSpace.sm),
                    Text('Alto en el camino',
                        style: TextStyle(
                            fontFamily: 'Marcellus', fontSize: 17, color: accent.withValues(alpha: 0.95))),
                    const Spacer(),
                    Text('El jugador decide el orden', style: EditorType.meta),
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

class _HubPageChrome extends StatelessWidget {
  const _HubPageChrome({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F151B),
        iconTheme: IconThemeData(color: accent),
        title: Text('Alto en el camino',
            style: TextStyle(fontFamily: 'Marcellus', fontSize: 17, color: accent.withValues(alpha: 0.95))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AetherSpace.lg, AetherSpace.lg, AetherSpace.lg, AetherSpace.huge),
        child: child,
      ),
    );
  }
}

class _HubForm extends StatefulWidget {
  const _HubForm({
    required this.initialTitle,
    required this.initialNode,
    required this.nodeTitles,
    required this.worldAttributeKeys,
  });

  final String initialTitle;
  final StateHubNode initialNode;
  final Map<String, String> nodeTitles;
  final List<String> worldAttributeKeys;

  @override
  State<_HubForm> createState() => _HubFormState();
}

class _HubFormState extends State<_HubForm> {
  late final _titleController = TextEditingController(text: widget.initialTitle);
  late List<HubActivity> _activities = widget.initialNode.activities;
  late List<StoryChoice> _exits = widget.initialNode.exits;
  int _nextActivitySeq = 1;

  @override
  void initState() {
    super.initState();
    _nextActivitySeq = _activities.length + 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  StoryChoice _choiceLikeFromActivity(HubActivity activity) => StoryChoice(
        label: activity.label,
        targetNodeId: '',
        gate: activity.gate,
        effects: activity.effects,
        resultText: activity.resultText,
        checkAttribute: activity.checkAttribute,
        checkDifficulty: activity.checkDifficulty,
        onSuccess: activity.onSuccess,
        onCriticalSuccess: activity.onCriticalSuccess,
        onFailure: activity.onFailure,
        advantageWhen: activity.advantageWhen,
        disadvantageWhen: activity.disadvantageWhen,
      );

  HubActivity _activityFromChoiceLike(String id, StoryChoice choice, {required bool repeatable}) =>
      HubActivity(
        id: id,
        label: choice.label,
        gate: choice.gate,
        effects: choice.effects,
        resultText: choice.resultText,
        repeatable: repeatable,
        checkAttribute: choice.checkAttribute,
        checkDifficulty: choice.checkDifficulty,
        onSuccess: choice.onSuccess,
        onCriticalSuccess: choice.onCriticalSuccess,
        onFailure: choice.onFailure,
        advantageWhen: choice.advantageWhen,
        disadvantageWhen: choice.disadvantageWhen,
      );

  Future<void> _addActivity() async {
    var repeatable = true;
    final choice = await ChoiceEditorScreen.openForActivity(
      context,
      initialAsChoice: null,
      worldAttributeKeys: widget.worldAttributeKeys,
      accent: EditorNodeColors.stateHub,
      initialRepeatable: repeatable,
      onRepeatableChanged: (v) => repeatable = v,
    );
    if (choice != null) {
      final id = 'a${_nextActivitySeq++}';
      setState(() {
        _activities = [..._activities, _activityFromChoiceLike(id, choice, repeatable: repeatable)];
      });
    }
  }

  Future<void> _editActivityAt(int index) async {
    final activity = _activities[index];
    var repeatable = activity.repeatable;
    final choice = await ChoiceEditorScreen.openForActivity(
      context,
      initialAsChoice: _choiceLikeFromActivity(activity),
      worldAttributeKeys: widget.worldAttributeKeys,
      accent: EditorNodeColors.stateHub,
      initialRepeatable: repeatable,
      onRepeatableChanged: (v) => repeatable = v,
    );
    if (choice != null) {
      setState(() {
        final updated = [..._activities];
        updated[index] = _activityFromChoiceLike(activity.id, choice, repeatable: repeatable);
        _activities = updated;
      });
    }
  }

  Future<void> _addExit() async {
    final choice = await ChoiceEditorScreen.open(
      context,
      initial: null,
      nodeTitles: widget.nodeTitles,
      worldAttributeKeys: widget.worldAttributeKeys,
      accent: EditorNodeColors.stateHub,
    );
    if (choice != null) setState(() => _exits = [..._exits, choice]);
  }

  Future<void> _editExitAt(int index) async {
    final choice = await ChoiceEditorScreen.open(
      context,
      initial: _exits[index],
      nodeTitles: widget.nodeTitles,
      worldAttributeKeys: widget.worldAttributeKeys,
      accent: EditorNodeColors.stateHub,
    );
    if (choice != null) {
      setState(() {
        final updated = [..._exits];
        updated[index] = choice;
        _exits = updated;
      });
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop((
      title: title,
      node: StateHubNode(
        id: widget.initialNode.id,
        activities: _activities,
        exits: _exits,
        codexReveals: widget.initialNode.codexReveals,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const accent = EditorNodeColors.stateHub;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cómo se llama', style: EditorType.overline),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          style: const TextStyle(fontFamily: 'Marcellus', fontSize: 18, color: Color(0xFFA9EDF6)),
          decoration: _hubFieldDecoration(),
        ),
        const SizedBox(height: AetherSpace.lg),
        Row(
          children: [
            Expanded(child: Text('Cosas que puede hacer, en cualquier orden', style: EditorType.overline)),
            InkWell(
              onTap: _addActivity,
              child: const Icon(Icons.add_circle_outline_rounded, size: 18, color: accent),
            ),
          ],
        ),
        const SizedBox(height: AetherSpace.sm),
        if (_activities.isEmpty) Text('Todavía no hay ninguna.', style: AetherType.caption),
        for (final (i, activity) in _activities.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _ActivityCard(
              activity: activity,
              onTap: () => _editActivityAt(i),
              onRemove: () => setState(() => _activities = [..._activities]..removeAt(i)),
            ),
          ),
        const SizedBox(height: AetherSpace.lg),
        Row(
          children: [
            Expanded(child: Text('Salidas · lo único que mueve la historia', style: EditorType.overline)),
            InkWell(
              onTap: _addExit,
              child: const Icon(Icons.add_circle_outline_rounded, size: 18, color: accent),
            ),
          ],
        ),
        const SizedBox(height: AetherSpace.sm),
        if (_exits.isEmpty) Text('Todavía no hay ninguna.', style: AetherType.caption),
        for (final (i, exit) in _exits.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _ExitCard(
              choice: exit,
              targetTitle: widget.nodeTitles[exit.targetNodeId] ?? exit.targetNodeId,
              onTap: () => _editExitAt(i),
              onRemove: () => setState(() => _exits = [..._exits]..removeAt(i)),
            ),
          ),
        const SizedBox(height: AetherSpace.lg),
        Container(
          padding: const EdgeInsets.all(AetherSpace.sm + 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0F151B),
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 17, color: Color(0xFF7C8F99)),
              const SizedBox(width: AetherSpace.sm),
              Expanded(
                child: Text(
                  'Hacer cosas aquí no avanza la historia — sólo cambia el estado del personaje.',
                  style: AetherType.caption.copyWith(color: const Color(0xFF7C8F99)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AetherSpace.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: const Color(0xFF080B0F),
                shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
              ),
              child:
                  Text('Guardar alto', style: EditorType.button.copyWith(color: const Color(0xFF080B0F))),
            ),
          ],
        ),
      ],
    );
  }
}

InputDecoration _hubFieldDecoration() => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm + 3),
      filled: true,
      fillColor: const Color(0xFF0F151B),
      enabledBorder: OutlineInputBorder(
        borderRadius: AetherRadius.allMd,
        borderSide: BorderSide(color: EditorNodeColors.stateHub.withValues(alpha: 0.28)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AetherRadius.allMd,
        borderSide: const BorderSide(color: EditorNodeColors.stateHub),
      ),
    );

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.onTap, required this.onRemove});

  final HubActivity activity;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Container(
        padding: const EdgeInsets.all(AetherSpace.sm + 3),
        decoration: BoxDecoration(
          color: const Color(0xFF0F151B),
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: EditorNodeColors.stateHub.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(activity.label,
                      style: AetherType.body.copyWith(fontSize: 13, color: const Color(0xFFDCEBE7))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: EditorNodeColors.stateHub.withValues(alpha: 0.1),
                    borderRadius: AetherRadius.allSm,
                  ),
                  child: Text(activity.repeatable ? 'se puede repetir' : 'una sola vez',
                      style: EditorType.pill.copyWith(fontSize: 9.5)),
                ),
                InkWell(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.close_rounded, size: 15, color: AetherColors.parchmentFaint),
                  ),
                ),
              ],
            ),
            if (activity.checkAttribute != null || activity.gate is! AlwaysGate) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  if (activity.checkAttribute != null) ...[
                    const Icon(Icons.casino_rounded, size: 13, color: Color(0xFF7C8F99)),
                    const SizedBox(width: 4),
                    Text('${activity.checkAttribute} · ${activity.checkDifficulty}',
                        style: EditorType.pill.copyWith(color: const Color(0xFF7C8F99))),
                  ],
                  if (activity.gate is! AlwaysGate) ...[
                    if (activity.checkAttribute != null) const SizedBox(width: 8),
                    const Icon(Icons.visibility_rounded, size: 13, color: Color(0xFF7C8F99)),
                    const SizedBox(width: 4),
                    Text('condicional', style: EditorType.pill.copyWith(color: const Color(0xFF7C8F99))),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExitCard extends StatelessWidget {
  const _ExitCard({
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
          color: EditorNodeColors.stateHub.withValues(alpha: 0.05),
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: EditorNodeColors.stateHub.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, size: 16, color: EditorNodeColors.stateHub),
            const SizedBox(width: AetherSpace.sm),
            Expanded(
              child: Text(choice.label,
                  style: AetherType.body.copyWith(fontSize: 12.5, color: const Color(0xFFDCEBE7))),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF7C8F99)),
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
