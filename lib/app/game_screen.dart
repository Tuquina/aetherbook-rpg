import 'package:flutter/material.dart';

import '../core/narrative/story_choice.dart';
import 'codex_screen.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'widgets/atmosphere.dart';
import 'widgets/choice_button.dart';
import 'widgets/fate_roll.dart';
import 'widgets/status_bar.dart';
import 'world_select_screen.dart';

/// The single play screen: an atmospheric backdrop, the status bar up top, the
/// narration (with the Fate Roll reveal) in the middle, and the choices at the
/// foot (GDD §9). Rebuilds from the [GameController] via [ListenableBuilder] —
/// no extra state-mgmt package.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller, this.worldSlug = 'xianxia'});

  final GameController controller;

  /// Only used when the controller hasn't already been started elsewhere —
  /// a curated world's [ChargenScreen] starts the session itself (with the
  /// player's chargen input) before navigating here, so this screen must not
  /// re-`start()` and discard that session.
  final String worldSlug;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _freeAction = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _lastNarration = '';

  /// Whether the choices for the *current* turn are allowed to show yet. On
  /// mobile, a reader can blow past the prose to the buttons at the bottom
  /// without ever reading it — so each new turn starts with choices hidden
  /// behind a "keep reading" hint, and they unlock (and then stay put, no
  /// re-hiding on scrolling back up) once the player reaches the bottom of
  /// the narration. Short text that doesn't overflow the viewport at all
  /// unlocks immediately — there's nothing to scroll through.
  bool _choicesRevealed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _scroll.addListener(_onScroll);
    if (!widget.controller.isReady) {
      widget.controller.start(widget.worldSlug);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _scroll.removeListener(_onScroll);
    _freeAction.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Scroll the narration back to the top when a new turn arrives, so the
  /// Fate Roll and fresh prose are in view, and re-arm the reveal gate for
  /// it.
  void _onControllerChange() {
    final narration = widget.controller.narration;
    if (narration != _lastNarration) {
      _lastNarration = narration;
      setState(() => _choicesRevealed = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(0,
            duration: AetherMotion.slow, curve: AetherMotion.standard);
        if (_scroll.position.maxScrollExtent <= 0 && mounted) {
          setState(() => _choicesRevealed = true);
        }
      });
    }
  }

  void _onScroll() {
    if (_choicesRevealed || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 24) {
      setState(() => _choicesRevealed = true);
    }
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
      body: AetherBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            if (!c.isReady && c.isLoading) {
              return const SafeArea(child: Center(child: DestinyWriting()));
            }
            if (c.error != null && !c.isReady) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AetherSpace.xl),
                  child: Center(
                    child: Text(c.error!,
                        style: AetherType.body, textAlign: TextAlign.center),
                  ),
                ),
              );
            }
            return _ReadingFrame(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatusBar(
                      world: c.world!,
                      character: c.character!,
                      onOpenCodex: () =>
                          Navigator.of(context).push(CodexScreen.route()),
                      onBack: () => Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          transitionDuration: AetherMotion.slow,
                          pageBuilder: (_, _, _) =>
                              WorldSelectScreen(controller: c),
                          transitionsBuilder: (_, anim, _, child) =>
                              FadeTransition(opacity: anim, child: child),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _NarrationView(controller: c, scroll: _scroll),
                    ),
                    if (c.isLoading || _choicesRevealed)
                      _ChoicesBar(
                        controller: c,
                        freeAction: _freeAction,
                        onSubmitFree: _submitFreeAction,
                      )
                    else
                      const _KeepReadingHint(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Keeps the game a comfortable reading width on any screen. On phones it's
/// edge-to-edge as designed; on wide screens (web/desktop) the same layout is
/// centered in a framed "codex page" so it reads like an open tome instead of
/// stretching across the whole window — the mobile design is never altered,
/// only bounded and framed.
class _ReadingFrame extends StatelessWidget {
  const _ReadingFrame({required this.child});

  final Widget child;

  static const double _maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _maxWidth) return child;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AetherSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AetherRadius.allLg,
              border: Border.all(color: AetherColors.hairlineStrong),
              boxShadow: AetherShadow.panel,
            ),
            child: ClipRRect(
              borderRadius: AetherRadius.allLg,
              child: ColoredBox(color: AetherColors.ink, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _NarrationView extends StatelessWidget {
  const _NarrationView({required this.controller, required this.scroll});

  final GameController controller;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final resolution = controller.lastResolution;
    return SingleChildScrollView(
      key: const Key('narrationScroll'),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.xl, AetherSpace.xl, AetherSpace.xl, AetherSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (resolution != null) ...[
            FateRoll(
              key: ValueKey(resolution),
              resolution: resolution,
              criticalMargin: controller.world!.criticalMargin,
            ),
            if (controller.lastLevelsGained > 0)
              Padding(
                padding: const EdgeInsets.only(top: AetherSpace.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LevelUpBanner(
                      levelsGained: controller.lastLevelsGained,
                      unitLabel: controller.world!.progression.unitLabel),
                ),
              ),
            const SizedBox(height: AetherSpace.xl),
          ],
          AnimatedSwitcher(
            duration: AetherMotion.slow,
            switchInCurve: AetherMotion.standard,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                        begin: const Offset(0, 0.03), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: Text(
              controller.narration,
              key: ValueKey(controller.narration),
              style: AetherType.narration,
            ),
          ),
          if (controller.error != null) ...[
            const SizedBox(height: AetherSpace.lg),
            Text(controller.error!,
                style: AetherType.body.copyWith(color: AetherColors.failure)),
          ],
        ],
      ),
    );
  }
}

/// Sits where [_ChoicesBar] would, before the player has scrolled through
/// the current turn's prose — a quiet nudge, not a wall, so the app doesn't
/// look broken when the buttons are simply not there yet.
class _KeepReadingHint extends StatelessWidget {
  const _KeepReadingHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AetherSpace.lg, vertical: AetherSpace.lg),
      decoration: const BoxDecoration(
        color: AetherColors.surface,
        border: Border(top: BorderSide(color: AetherColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Seguí leyendo',
                style: AetherType.caption.copyWith(color: AetherColors.parchmentFaint)),
            const SizedBox(width: AetherSpace.xs),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AetherColors.parchmentFaint),
          ],
        ),
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

  /// Resolves a tapped [StoryChoice], first asking for confirmation when it's
  /// marked irreversible (campaign-bible §20.3/§26.4) — a curated author's
  /// `confirmation_text`, or a generic fallback if the choice declares none.
  Future<void> _tapStoryChoice(BuildContext context, StoryChoice choice) async {
    if (!choice.requiresConfirmation) {
      controller.chooseStoryChoice(choice);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AetherColors.surface,
        content: Text(
          choice.confirmationText ?? '¿Confirmás esta decisión? No se puede deshacer.',
          style: AetherType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.chooseStoryChoice(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = controller.isLoading;
    // A curated (hybrid-campaign) world offers deterministic story
    // choices/hub activities instead of the AI's suggested_choices. The
    // free-action field stays available on top of them by default
    // (campaign-bible §18.10: "la acción libre permanece siempre
    // disponible") — a fully curated, AI-free world (§25.10) turns it off
    // entirely via `World.allowFreeText`.
    final curated = controller.currentNode != null;
    final allowFreeText = controller.world?.allowFreeText ?? true;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.lg, AetherSpace.md, AetherSpace.lg, AetherSpace.lg),
      decoration: const BoxDecoration(
        color: AetherColors.surface,
        border: Border(top: BorderSide(color: AetherColors.hairline)),
        boxShadow: AetherShadow.panel,
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: AetherMotion.base,
          curve: AetherMotion.standard,
          alignment: Alignment.bottomCenter,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AetherSpace.lg),
                  child: DestinyWriting(),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A state_hub can offer many activities/exits at once
                    // (unlike a freeform AI turn, capped at 3 suggestions) —
                    // bounded + scrollable so it never overflows the screen.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (curated) ...[
                              for (final choice in controller.availableStoryChoices)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: AetherSpace.md),
                                  child: ChoiceButton(
                                    label: choice.label,
                                    onTap: () => _tapStoryChoice(context, choice),
                                  ),
                                ),
                              for (final activity in controller.availableActivities)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: AetherSpace.md),
                                  child: ChoiceButton(
                                    label: activity.label,
                                    onTap: () =>
                                        controller.chooseHubActivity(activity),
                                  ),
                                ),
                            ] else
                              for (final choice in controller.choices)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: AetherSpace.md),
                                  child: ChoiceButton(
                                    label: choice,
                                    onTap: () => controller.choose(choice),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    if (allowFreeText) ...[
                      const SizedBox(height: AetherSpace.xs),
                      FreeActionField(
                          controller: freeAction, onSubmit: onSubmitFree),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
