import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../design/editor_tokens.dart';

/// A "which scene does this lead to" picker (V2 design prototype §9b's
/// target field, §9g's "Si se le acaban, sale a", §9h's exits) — every
/// choice/exit/fallback-exit target field in the editor is this same
/// dropdown of `nodeTitles` (id -> display title).
class NodeTargetDropdown extends StatelessWidget {
  const NodeTargetDropdown({
    super.key,
    required this.value,
    required this.nodeTitles,
    required this.onChanged,
    this.label,
  });

  final String? value;
  final Map<String, String> nodeTitles;
  final ValueChanged<String?> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: EditorType.overline),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm + 2),
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allSm,
            border: Border.all(color: AetherColors.hairline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: nodeTitles.containsKey(value) ? value : null,
              isExpanded: true,
              hint: Text('Elegí una escena', style: AetherType.caption),
              dropdownColor: AetherColors.surface,
              style: AetherType.body.copyWith(fontSize: 13, color: AetherColors.parchment),
              items: [
                for (final entry in nodeTitles.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
