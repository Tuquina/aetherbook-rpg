import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Resolves a vow's `character.varValue('vow_status')`/`meter('vow_tested_count')`
/// pair (Stage B, `core/engine/apply_state_deltas.dart`'s `vowStatus` delta
/// case) into what to show for it — shared by the ending-reveal overlay
/// (`game_screen.dart`'s `_EndingVowStat`), Perfil's vow history
/// (`profile_screen.dart`'s `_VowCard`) and `CharacterSheetSheet`, which
/// previously each had their own copy of this switch.
///
/// [status] is `null` for a vow that has never been tested at all — the
/// case both previous copies of this switch fell through to their
/// "puesto a prueba" branch for, misreporting an intact vow as "puesto a
/// prueba 0 veces". This is the one genuinely new branch; the other three
/// keep the exact wording/colors already shipped.
({Color color, IconData icon, String label}) resolveVowStatus(
  String? status,
  int testedCount,
) {
  return switch (status) {
    'roto' => (color: AetherColors.failure, icon: Icons.warning_rounded, label: 'Roto'),
    'sostenido' => (
        color: AetherColors.success,
        icon: Icons.check_circle_rounded,
        label: 'Sostenido hasta el final',
      ),
    'puesto_a_prueba' => (
        color: AetherColors.failure,
        icon: Icons.warning_rounded,
        label: 'Puesto a prueba ${testedCount == 1 ? "una vez" : "$testedCount veces"}',
      ),
    _ => (
        color: AetherColors.parchmentDim,
        icon: Icons.shield_outlined,
        label: 'Intacto',
      ),
  };
}
