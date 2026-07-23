import 'package:flutter/material.dart';

import '../core/engine/action_resolution.dart';
import 'game_controller.dart';
import 'theme.dart';

/// The single play screen: narration up top (scrollable), a compact character
/// sheet, and the choices as large buttons at the foot (GDD §9). Rebuilds from
/// the [GameController] via [ListenableBuilder] — no extra state-mgmt package.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _freeAction = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.start('xianxia');
  }

  @override
  void dispose() {
    _freeAction.dispose();
    super.dispose();
  }

  void _submitFreeAction() {
    final text = _freeAction.text.trim();
    if (text.isEmpty) return;
    _freeAction.clear();
    FocusScope.of(context).unfocus();
    widget.controller.choose(text);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            if (!c.isReady && c.isLoading) {
              return const _Centered(child: _DestinyWriting());
            }
            if (c.error != null && !c.isReady) {
              return _Centered(child: Text(c.error!));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(controller: c),
                Expanded(child: _NarrationView(controller: c)),
                _ChoicesBar(
                  controller: c,
                  freeAction: _freeAction,
                  onSubmitFree: _submitFreeAction,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final world = controller.world;
    final ch = controller.character;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x33C9A24B)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            world?.name ?? 'Aetherbook',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (ch != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Stat(label: ch.name, value: 'Nivel ${ch.level}'),
                _Stat(label: 'EXP', value: '${ch.exp}'),
                for (final entry in ch.resources.entries)
                  _Stat(label: entry.key, value: '${entry.value}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(color: Color(0x99EDE6D6), fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AetherTheme.goldSoft,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NarrationView extends StatelessWidget {
  const _NarrationView({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.lastResolution != null)
            _OutcomeChip(resolution: controller.lastResolution!),
          if (controller.lastLevelsGained > 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _LevelUpChip(),
            ),
          const SizedBox(height: 12),
          // A gentle fade each time the narration changes.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              controller.narration,
              key: ValueKey(controller.narration),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 16),
            Text(
              controller.error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({required this.resolution});

  final ActionResolution resolution;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (resolution.outcome) {
      ActionOutcome.criticalSuccess => ('Éxito crítico', AetherTheme.gold),
      ActionOutcome.success => ('Éxito', const Color(0xFF7FB77E)),
      ActionOutcome.failure => ('Falla', const Color(0xFFB77E7E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$label (${resolution.attributeKey})  ·  d20 ${resolution.roll} → '
        '${resolution.total} vs ${resolution.difficulty}',
        style: TextStyle(color: color, fontSize: 12.5),
      ),
    );
  }
}

class _LevelUpChip extends StatelessWidget {
  const _LevelUpChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AetherTheme.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '⬆  Has avanzado de reino',
        style: TextStyle(color: AetherTheme.goldSoft, fontSize: 12.5),
      ),
    );
  }
}

class _ChoicesBar extends StatelessWidget {
  const _ChoicesBar({
    required this.controller,
    required this.freeAction,
    required this.onSubmitFree,
  });

  final GameController controller;
  final TextEditingController freeAction;
  final VoidCallback onSubmitFree;

  @override
  Widget build(BuildContext context) {
    final busy = controller.isLoading;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AetherTheme.inkSoft,
        border: Border(top: BorderSide(color: Color(0x33C9A24B))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: _DestinyWriting(),
            )
          else ...[
            for (final choice in controller.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChoiceButton(
                  label: choice,
                  onTap: () => controller.choose(choice),
                ),
              ),
            const SizedBox(height: 4),
            _FreeActionField(
              controller: freeAction,
              onSubmit: onSubmitFree,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          alignment: Alignment.centerLeft,
          side: const BorderSide(color: Color(0x55C9A24B)),
          foregroundColor: AetherTheme.parchment,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class _FreeActionField extends StatelessWidget {
  const _FreeActionField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onSubmit(),
      style: const TextStyle(color: AetherTheme.parchment),
      decoration: InputDecoration(
        hintText: 'O escribí tu propia acción…',
        hintStyle: const TextStyle(color: Color(0x66EDE6D6)),
        filled: true,
        fillColor: AetherTheme.ink,
        suffixIcon: IconButton(
          icon: const Icon(Icons.send, color: AetherTheme.gold, size: 20),
          onPressed: onSubmit,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x33C9A24B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AetherTheme.gold),
        ),
      ),
    );
  }
}

/// The "el destino se escribe…" loading indicator (GDD §9: never a frozen
/// screen).
class _DestinyWriting extends StatelessWidget {
  const _DestinyWriting();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AetherTheme.gold,
          ),
        ),
        SizedBox(width: 12),
        Text(
          'El destino se escribe…',
          style: TextStyle(color: AetherTheme.goldSoft, fontSize: 14),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(24), child: Center(child: child));
}
