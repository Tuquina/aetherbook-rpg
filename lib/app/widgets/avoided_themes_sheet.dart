import 'package:flutter/material.dart';

import '../../core/settings/user_settings.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'sheet_shell.dart';

/// A checklist over [UserSettings.avoidedThemeCatalog] (V2 design prototype
/// §6b's "Temas que el narrador evita" row) — a bottom sheet rather than a
/// full screen so Ajustes stays within the app's "5 new screens" scope while
/// the control itself is still real (the result reaches the narrator prompt
/// as `NarratorRequest.avoidedThemes`, see `GameController`'s narrate call).
///
/// Returns the updated selection, or `null` if the sheet was dismissed
/// without confirming — the caller (`SettingsScreen`) only saves on a
/// non-null result.
Future<List<String>?> showAvoidedThemesSheet(
  BuildContext context, {
  required List<String> current,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AetherColors.void_.withValues(alpha: 0.72),
    isScrollControlled: true,
    builder: (_) => SheetShell(
      title: 'Temas que el narrador evita',
      child: _AvoidedThemesBody(initial: current),
    ),
  );
}

class _AvoidedThemesBody extends StatefulWidget {
  const _AvoidedThemesBody({required this.initial});

  final List<String> initial;

  @override
  State<_AvoidedThemesBody> createState() => _AvoidedThemesBodyState();
}

class _AvoidedThemesBodyState extends State<_AvoidedThemesBody> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg),
            children: [
              Text(
                'El narrador nunca representa en detalle lo que marques acá. '
                'Podés cambiar esto cuando quieras.',
                style: AetherType.body.copyWith(color: AetherColors.parchmentDim, fontSize: 13),
              ),
              const SizedBox(height: AetherSpace.md),
              for (final theme in UserSettings.avoidedThemeCatalog)
                CheckboxListTile(
                  value: _selected.contains(theme.id),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _selected.add(theme.id);
                    } else {
                      _selected.remove(theme.id);
                    }
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AetherColors.gold,
                  checkColor: AetherColors.ink,
                  contentPadding: EdgeInsets.zero,
                  title: Text(theme.label, style: AetherType.label.copyWith(fontSize: 14)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AetherSpace.lg, AetherSpace.sm, AetherSpace.lg, AetherSpace.xl),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected.toList()),
              style: FilledButton.styleFrom(
                backgroundColor: AetherColors.gold,
                foregroundColor: AetherColors.ink,
                padding: const EdgeInsets.symmetric(vertical: AetherSpace.md),
                shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
              ),
              child: const Text('Guardar'),
            ),
          ),
        ),
      ],
    );
  }
}
