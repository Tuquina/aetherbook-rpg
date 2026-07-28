import 'package:flutter/material.dart';

import '../core/engine/action_resolution.dart';
import '../ports/settings_port.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'widgets/atmosphere.dart';
import 'widgets/brand_mark.dart';
import 'widgets/fate_roll.dart';
import 'widgets/step_dots.dart';
import 'world_select_screen.dart';

/// The 3-page first-run flow (V2 design prototype §6c-e) — no feature tour,
/// no menu of settings: a promise ("no vas to elegir entre A y B"), a live
/// demo of the one mechanic every world shares (the dice check), and the
/// first real choice (how to start). Gated exactly once per account by
/// default — `SplashScreen` only routes here on `!UserSettings.hasSeenOnboarding`,
/// and this screen is what flips that flag, whether the player finishes it
/// or skips — but it's also reachable on demand, any number of times, from
/// `SettingsScreen`'s "Ver la introducción otra vez" (your explicit request:
/// a one-time flow shouldn't mean a one-time-*ever* flow). [onDone] is what
/// tells these two call sites apart: `SplashScreen` uses it to move on to
/// `WorldSelectScreen`; a replay from Settings just pops back.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.controller,
    required this.settingsPort,
    required this.onDone,
  });

  final GameController controller;
  final SettingsPort settingsPort;

  /// Called once onboarding is finished or skipped. [module] is the story
  /// type the player tapped on the last page (`null` if they skipped
  /// instead) — the caller opens `WorldSelectScreen` either way, with
  /// [module] as its `autoOpenModule` when set.
  final void Function(StoryModule? module) onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

const _pageCount = 3;

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  void _markSeen() {
    final next = widget.controller.settings.copyWith(hasSeenOnboarding: true);
    widget.controller.updateSettings(next);
    // Fire-and-forget: onboarding must never block on a network round trip
    // just to flip a flag the player has already moved past.
    widget.settingsPort.saveSettings(next);
  }

  void _skip() {
    _markSeen();
    widget.onDone(null);
  }

  void _next() {
    if (_page < _pageCount - 1) {
      setState(() => _page++);
      return;
    }
    _markSeen();
    widget.onDone(null);
  }

  void _choose(StoryModule module) {
    _markSeen();
    widget.onDone(module);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        particles: false,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: AetherMotion.slow,
            child: KeyedSubtree(
              key: ValueKey(_page),
              child: switch (_page) {
                0 => _PromisePage(onNext: _next, onSkip: _skip),
                1 => _DiceDemoPage(onNext: _next, onSkip: _skip),
                _ => _ChooseStartPage(onChoose: _choose),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PromisePage extends StatelessWidget {
  const _PromisePage({required this.onNext, required this.onSkip});

  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AetherSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandMark(size: 56, filled: false),
              const SizedBox(height: AetherSpace.xl),
              Text('No vas a elegir entre A y B',
                  style: AetherType.display.copyWith(fontSize: 28)),
              const SizedBox(height: AetherSpace.md),
              Text(
                'Escribes lo que se te ocurra y el mundo responde. Si mientes, '
                'alguien lo va a recordar. Si rompes algo, sigue roto en el '
                'capítulo doce.',
                style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
              ),
              const SizedBox(height: AetherSpace.xxl),
              const StepDots(count: _pageCount, current: 0, highlightCurrentOnly: true),
              const SizedBox(height: AetherSpace.lg),
              _PrimaryButton(label: 'Sigue', onTap: onNext),
              const SizedBox(height: AetherSpace.md),
              Center(child: _SkipLink(onTap: onSkip)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiceDemoPage extends StatelessWidget {
  const _DiceDemoPage({required this.onNext, required this.onSkip});

  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const _demoResolution = ActionResolution(
    outcome: ActionOutcome.failure,
    attributeKey: 'sigilo',
    attribute: 3,
    modifiers: 0,
    roll: 7,
    difficulty: 12,
    total: 10,
    isNatural20: false,
    isNatural1: false,
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AetherSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _SkipLink(onTap: onSkip),
              ),
              Text('PRUÉBALO',
                  style: AetherType.overline.copyWith(letterSpacing: 2.2)),
              const SizedBox(height: AetherSpace.sm),
              Text('Cuando puede salir mal', style: AetherType.display.copyWith(fontSize: 26)),
              const SizedBox(height: AetherSpace.md),
              Text(
                'El narrador tira 1d20 y le suma tu atributo. Nada te saca de '
                'la historia: un fallo la tuerce, no la corta.',
                style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
              ),
              const SizedBox(height: AetherSpace.lg),
              Text(
                'Intentas cruzar el portón sin que el anciano te vea la muñeca.',
                style: AetherType.body.copyWith(
                    color: AetherColors.parchmentDim, fontStyle: FontStyle.italic, fontSize: 14),
              ),
              const SizedBox(height: AetherSpace.md),
              const FateRoll(key: ValueKey('onboarding-demo-roll'), resolution: _demoResolution),
              const SizedBox(height: AetherSpace.xl),
              const StepDots(count: _pageCount, current: 1, highlightCurrentOnly: true),
              const SizedBox(height: AetherSpace.lg),
              _PrimaryButton(label: 'Sigue', onTap: onNext),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChooseStartPage extends StatelessWidget {
  const _ChooseStartPage({required this.onChoose});

  final ValueChanged<StoryModule> onChoose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AetherSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ÚLTIMA COSA', style: AetherType.overline.copyWith(letterSpacing: 2.2)),
              const SizedBox(height: AetherSpace.sm),
              Text('¿Cómo quieres empezar?', style: AetherType.display.copyWith(fontSize: 26)),
              const SizedBox(height: AetherSpace.md),
              Text(
                'Puedes cambiar de forma cuando quieras. Todas están explicadas '
                'en el Códice.',
                style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
              ),
              const SizedBox(height: AetherSpace.xl),
              _StartOption(
                icon: Icons.auto_stories_rounded,
                iconColor: AetherColors.goldBright,
                title: 'Una historia completa',
                description:
                    'Personaje y arco ya escritos. La forma más rápida de entender el ritmo.',
                highlighted: true,
                badge: 'Sugerido',
                onTap: () => onChoose(StoryModule.complete),
              ),
              const SizedBox(height: AetherSpace.md),
              _StartOption(
                icon: Icons.workspaces_outline,
                iconColor: AetherColors.parchmentDim,
                title: 'Crear mi personaje',
                description: 'Eliges mundo, origen y juramento; la trama se acomoda a ti.',
                onTap: () => onChoose(StoryModule.aiNarrator),
              ),
              const SizedBox(height: AetherSpace.md),
              _StartOption(
                icon: Icons.edit_note_rounded,
                iconColor: AetherColors.nova,
                title: 'Inventar el mundo entero',
                description: 'Página en blanco. Más libre y más difícil.',
                onTap: () => onChoose(StoryModule.aiNarrator),
              ),
              const SizedBox(height: AetherSpace.xl),
              const StepDots(count: _pageCount, current: 2, highlightCurrentOnly: true),
              const SizedBox(height: AetherSpace.md),
              Text(
                'Elige una para entrar. El Códice queda siempre a mano en el menú.',
                style: AetherType.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartOption extends StatelessWidget {
  const _StartOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
    this.highlighted = false,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool highlighted;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allLg,
      child: Container(
        padding: const EdgeInsets.all(AetherSpace.lg),
        decoration: BoxDecoration(
          borderRadius: AetherRadius.allLg,
          color: highlighted ? AetherColors.surfaceRaised : AetherColors.surface,
          border: Border.all(
            color: highlighted
                ? AetherColors.gold.withValues(alpha: 0.5)
                : AetherColors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: AetherSpace.sm),
                Expanded(
                  child: Text(title, style: AetherType.title.copyWith(fontSize: 17)),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AetherColors.gold.withValues(alpha: 0.16),
                      borderRadius: AetherRadius.allSm,
                    ),
                    child: Text(
                      badge!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AetherColors.goldBright,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AetherSpace.sm),
            Text(description, style: AetherType.body.copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _SkipLink extends StatelessWidget {
  const _SkipLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text('Saltar',
          style: AetherType.caption.copyWith(color: AetherColors.parchmentFaint, fontSize: 12.5)),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AetherSpace.lg),
        decoration: BoxDecoration(
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: AetherColors.gold.withValues(alpha: 0.55)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AetherColors.surfaceRaised, AetherColors.ink],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AetherColors.goldBright, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(width: AetherSpace.sm),
            const Icon(Icons.arrow_forward_rounded, size: 18, color: AetherColors.goldBright),
          ],
        ),
      ),
    );
  }
}
