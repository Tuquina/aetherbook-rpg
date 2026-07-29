import 'package:flutter/material.dart';

import '../../../core/authoring/campaign_summaries.dart';
import '../../design/tokens.dart';
import '../design/editor_tokens.dart';

/// "Esto puede salir mal" (V2 design prototype §9b/§9e): the toggle that
/// turns a choice/activity from unconditional into a checked one, plus its
/// attribute dropdown and the 5 named-difficulty buttons. `attribute`/
/// `difficulty` are `null` exactly when the toggle is off — the caller maps
/// that straight onto `StoryChoice.checkAttribute`/`checkDifficulty`.
class CheckEditor extends StatelessWidget {
  const CheckEditor({
    super.key,
    required this.attribute,
    required this.difficulty,
    required this.worldAttributeKeys,
    required this.onChanged,
  });

  final String? attribute;
  final int? difficulty;
  final List<String> worldAttributeKeys;
  final void Function(String? attribute, int? difficulty) onChanged;

  bool get _enabled => attribute != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.md),
      decoration: BoxDecoration(
        color: const Color(0xFFD8B65E).withValues(alpha: 0.05),
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: const Color(0xFFD8B65E).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.casino_rounded, size: 19, color: Color(0xFFD8B65E)),
              const SizedBox(width: AetherSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Esto puede salir mal', style: EditorType.label),
                    Text('Se tira 1d20 + el atributo antes de resolver', style: EditorType.hint),
                  ],
                ),
              ),
              Switch(
                value: _enabled,
                activeThumbColor: const Color(0xFFD8B65E),
                onChanged: (v) => onChanged(
                  v ? (worldAttributeKeys.isNotEmpty ? worldAttributeKeys.first : '') : null,
                  v ? DifficultyPreset.dificil.value : null,
                ),
              ),
            ],
          ),
          if (_enabled) ...[
            const SizedBox(height: AetherSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CON QUÉ ATRIBUTO', style: EditorType.overline),
                      const SizedBox(height: 6),
                      DropdownButton<String>(
                        value: worldAttributeKeys.contains(attribute)
                            ? attribute
                            : (worldAttributeKeys.isEmpty ? null : worldAttributeKeys.first),
                        isExpanded: true,
                        dropdownColor: AetherColors.surface,
                        items: [
                          for (final key in worldAttributeKeys)
                            DropdownMenuItem(value: key, child: Text(key)),
                        ],
                        onChanged: (value) => onChanged(value, difficulty),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AetherSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUÉ TAN DIFÍCIL', style: EditorType.overline),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final preset in DifficultyPreset.values)
                            Expanded(
                              child: _DifficultyButton(
                                preset: preset,
                                selected: difficulty == preset.value,
                                onTap: () => onChanged(attribute, preset.value),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({required this.preset, required this.selected, required this.onTap});

  final DifficultyPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFD8B65E);
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allSm,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : null,
          borderRadius: AetherRadius.allSm,
          border: Border.all(color: selected ? color.withValues(alpha: 0.55) : AetherColors.hairline),
        ),
        child: Column(
          children: [
            Text(
              preset.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Archivo',
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? color : AetherColors.parchmentFaint,
              ),
            ),
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
