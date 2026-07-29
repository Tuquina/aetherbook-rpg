import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../design/editor_tokens.dart';

/// A row of removable string chips plus a "+ añadir" chip that turns into an
/// inline text field (V2 design prototype §9g: "Lugares"/"Gente"/"Problemas
/// que puede poner", each its own chip-list-with-add). Generic over what the
/// strings mean — the corridor editor uses it for free-text location/NPC/
/// obstacle names, `EditorLibraryScreen`'s content-warnings field reuses it
/// too.
class ChipListField extends StatefulWidget {
  const ChipListField({
    super.key,
    required this.values,
    required this.onChanged,
    this.accent = AetherColors.gold,
  });

  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final Color accent;

  @override
  State<ChipListField> createState() => _ChipListFieldState();
}

class _ChipListFieldState extends State<ChipListField> {
  bool _adding = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startAdding() {
    setState(() => _adding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _commit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      widget.onChanged([...widget.values, value]);
    }
    _controller.clear();
    setState(() => _adding = false);
  }

  void _removeAt(int index) {
    final updated = [...widget.values]..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, value) in widget.values.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AetherColors.surface,
              borderRadius: AetherRadius.allSm,
              border: Border.all(color: widget.accent.withValues(alpha: 0.26)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: EditorType.label.copyWith(color: AetherColors.parchment)),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _removeAt(i),
                  child: const Icon(Icons.close_rounded, size: 13, color: AetherColors.parchmentFaint),
                ),
              ],
            ),
          ),
        if (_adding)
          SizedBox(
            width: 140,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
              style: AetherType.body.copyWith(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(borderRadius: AetherRadius.allSm),
              ),
            ),
          )
        else
          InkWell(
            onTap: _startAdding,
            borderRadius: AetherRadius.allSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: AetherRadius.allSm,
                border: Border.all(color: AetherColors.hairlineStrong, style: BorderStyle.solid),
              ),
              child: Text('+ añadir',
                  style: EditorType.pill.copyWith(color: AetherColors.parchmentFaint)),
            ),
          ),
      ],
    );
  }
}
