import 'package:flutter/material.dart';

import '../core/settings/user_settings.dart';
import '../ports/auth_port.dart';
import '../ports/settings_port.dart';
import 'codex_screen.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'widgets/atmosphere.dart';
import 'widgets/avoided_themes_sheet.dart';
import 'widgets/sheet_shell.dart';

const _reminderFrequencyLabels = {
  'never': 'Nunca',
  'daily': 'Cada día',
  'every_3_days': 'Cada 3 días',
  'weekly': 'Una vez por semana',
};

/// Ajustes (V2 design prototype §6b) — every control here is wired to real
/// behavior, not a cosmetic toggle: reading preferences change
/// `GameScreen`'s own rendering, "Dureza del mundo"/"Sugerir acciones" reach
/// `GameController` directly (a real difficulty offset, a real prompt
/// change), and "Temas que el narrador evita" reaches the narrator prompt.
/// Saved account-wide via [SettingsPort] — `GameController.updateSettings`
/// is called immediately on every change so the current session reflects it
/// without waiting for the next app launch.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.settingsPort,
    required this.authPort,
  });

  final GameController controller;
  final SettingsPort settingsPort;
  final AuthPort authPort;

  static Route<void> route({
    required GameController controller,
    required SettingsPort settingsPort,
    required AuthPort authPort,
  }) =>
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          controller: controller,
          settingsPort: settingsPort,
          authPort: authPort,
        ),
      );

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserSettings _settings = widget.controller.settings;

  void _apply(UserSettings next) {
    setState(() => _settings = next);
    widget.controller.updateSettings(next);
    widget.settingsPort.saveSettings(next);
  }

  Future<void> _signOut() async {
    await widget.authPort.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(AetherSpace.xl),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: AetherColors.goldSoft),
                      ),
                      const SizedBox(width: AetherSpace.sm),
                      Text('Ajustes', style: AetherType.display.copyWith(fontSize: 22)),
                    ],
                  ),
                  const SizedBox(height: AetherSpace.xl),
                  const _SectionLabel('Cómo se lee'),
                  _SettingsCard(children: [
                    _TextSizeControl(
                      value: _settings.textScale,
                      onChanged: (v) => _apply(_settings.copyWith(textScale: v)),
                    ),
                    _Divider(),
                    _ToggleRow(
                      title: 'Aparecer el texto letra a letra',
                      subtitle: 'Se siente narrado; se puede saltar tocando.',
                      value: _settings.typewriterEffect,
                      onChanged: (v) => _apply(_settings.copyWith(typewriterEffect: v)),
                    ),
                    _Divider(),
                    _ToggleRow(
                      title: 'Ilustrar las escenas',
                      subtitle: 'Apagado, el tomo se lee sólo en texto.',
                      value: _settings.illustrateScenes,
                      onChanged: (v) => _apply(_settings.copyWith(illustrateScenes: v)),
                    ),
                  ]),
                  const SizedBox(height: AetherSpace.xl),
                  const _SectionLabel('Cómo narra'),
                  _SettingsCard(children: [
                    _HarshnessControl(
                      value: _settings.worldHarshness,
                      onChanged: (v) => _apply(_settings.copyWith(worldHarshness: v)),
                    ),
                    _Divider(),
                    _ToggleRow(
                      title: 'Sugerir acciones',
                      subtitle: 'Apagado, sólo escribes en texto libre.',
                      value: _settings.suggestActions,
                      onChanged: (v) => _apply(_settings.copyWith(suggestActions: v)),
                    ),
                    _Divider(),
                    _ToggleRow(
                      title: 'Mostrar la tirada',
                      subtitle: 'Apagado, el resultado llega sólo como relato.',
                      value: _settings.showTheRoll,
                      onChanged: (v) => _apply(_settings.copyWith(showTheRoll: v)),
                    ),
                  ]),
                  const SizedBox(height: AetherSpace.xl),
                  const _SectionLabel('Límites'),
                  _SettingsCard(children: [
                    _ChevronRow(
                      icon: Icons.shield_outlined,
                      title: 'Temas que el narrador evita',
                      subtitle: _settings.avoidedThemes.isEmpty
                          ? 'Ninguno marcado'
                          : '${_settings.avoidedThemes.length} temas marcados',
                      onTap: () async {
                        final result = await showAvoidedThemesSheet(
                          context,
                          current: _settings.avoidedThemes,
                        );
                        if (result != null) {
                          _apply(_settings.copyWith(avoidedThemes: result));
                        }
                      },
                    ),
                    _Divider(),
                    _ChevronRow(
                      icon: Icons.notifications_outlined,
                      title: 'Recordarme un tomo abierto',
                      subtitle: _reminderFrequencyLabels[_settings.reminderFrequency] ??
                          _settings.reminderFrequency,
                      onTap: () async {
                        final result = await _showReminderFrequencySheet(
                            context, _settings.reminderFrequency);
                        if (result != null) {
                          _apply(_settings.copyWith(reminderFrequency: result));
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: AetherSpace.xl),
                  _PlainRow(
                    icon: Icons.menu_book_outlined,
                    label: 'Volver a ver cómo se juega',
                    onTap: () => Navigator.of(context).push(CodexScreen.route()),
                  ),
                  _PlainRow(
                    icon: Icons.download_outlined,
                    label: 'Exportar mis tomos',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AetherColors.surfaceRaised,
                          content: Text('Todavía no está disponible.',
                              style: TextStyle(color: AetherColors.parchment)),
                        ),
                      );
                    },
                  ),
                  _PlainRow(
                    icon: Icons.logout_rounded,
                    label: 'Cerrar sesión',
                    color: AetherColors.failure,
                    onTap: _signOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _showReminderFrequencySheet(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AetherColors.void_.withValues(alpha: 0.72),
    isScrollControlled: true,
    builder: (_) => SheetShell(
      title: 'Recordarme un tomo abierto',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg, vertical: AetherSpace.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _reminderFrequencyLabels.entries)
              InkWell(
                onTap: () => Navigator.of(context).pop(entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AetherSpace.sm),
                  child: Row(
                    children: [
                      Icon(
                        entry.key == current
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: entry.key == current
                            ? AetherColors.gold
                            : AetherColors.parchmentFaint,
                      ),
                      const SizedBox(width: AetherSpace.md),
                      Text(entry.value, style: AetherType.label.copyWith(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AetherSpace.lg),
          ],
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AetherSpace.sm, left: AetherSpace.xs),
      child: Text(label, style: AetherType.overline),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allLg,
        border: Border.all(color: AetherColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(height: 1, color: AetherColors.hairline);
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg, vertical: AetherSpace.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AetherType.label.copyWith(fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AetherType.caption.copyWith(fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AetherColors.gold,
              thumbColor: WidgetStateProperty.all(AetherColors.goldBright),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChevronRow extends StatelessWidget {
  const _ChevronRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg, vertical: AetherSpace.md),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AetherColors.parchmentDim),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AetherType.label.copyWith(fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AetherType.caption.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AetherColors.parchmentFaint),
          ],
        ),
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AetherSpace.md, horizontal: AetherSpace.xs),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? AetherColors.parchmentFaint),
            const SizedBox(width: AetherSpace.md),
            Text(label,
                style: AetherType.label.copyWith(fontSize: 13, color: color ?? AetherColors.parchmentDim)),
          ],
        ),
      ),
    );
  }
}

class _TextSizeControl extends StatelessWidget {
  const _TextSizeControl({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AetherSpace.lg, AetherSpace.md, AetherSpace.lg, AetherSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tamaño del texto', style: AetherType.label.copyWith(fontSize: 13.5)),
          Row(
            children: [
              const Text('A', style: TextStyle(fontSize: 12, color: AetherColors.parchmentFaint)),
              Expanded(
                child: Slider(
                  value: value,
                  min: 0.8,
                  max: 1.3,
                  activeColor: AetherColors.gold,
                  inactiveColor: AetherColors.hairline,
                  onChanged: onChanged,
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 20, color: AetherColors.parchmentDim)),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm),
            decoration: BoxDecoration(
              color: AetherColors.void_,
              borderRadius: AetherRadius.allSm,
            ),
            child: Text(
              'La niebla baja desde la cumbre y trae olor a hierro frío.',
              style: AetherType.body.copyWith(fontSize: 14 * value, color: AetherColors.parchmentDim),
            ),
          ),
        ],
      ),
    );
  }
}

class _HarshnessControl extends StatelessWidget {
  const _HarshnessControl({required this.value, required this.onChanged});

  final WorldHarshness value;
  final ValueChanged<WorldHarshness> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AetherSpace.lg, AetherSpace.md, AetherSpace.lg, AetherSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dureza del mundo', style: AetherType.label.copyWith(fontSize: 13.5)),
          const SizedBox(height: 2),
          Text('Cuánto castiga una tirada fallida.',
              style: AetherType.caption.copyWith(fontSize: 12)),
          const SizedBox(height: AetherSpace.md),
          Row(
            children: [
              for (final harshness in WorldHarshness.values) ...[
                if (harshness != WorldHarshness.values.first) const SizedBox(width: AetherSpace.sm),
                Expanded(
                  child: _HarshnessChip(
                    label: switch (harshness) {
                      WorldHarshness.indulgente => 'Indulgente',
                      WorldHarshness.justo => 'Justo',
                      WorldHarshness.cruel => 'Cruel',
                    },
                    selected: harshness == value,
                    onTap: () => onChanged(harshness),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HarshnessChip extends StatelessWidget {
  const _HarshnessChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AetherSpace.sm),
        decoration: BoxDecoration(
          color: selected ? AetherColors.gold.withValues(alpha: 0.16) : null,
          border: Border.all(
            color: selected ? AetherColors.gold.withValues(alpha: 0.5) : AetherColors.hairline,
          ),
          borderRadius: AetherRadius.allMd,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AetherType.label.copyWith(
            fontSize: 12,
            color: selected ? AetherColors.goldBright : AetherColors.parchmentFaint,
          ),
        ),
      ),
    );
  }
}
