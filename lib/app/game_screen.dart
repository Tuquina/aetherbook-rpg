import 'package:flutter/material.dart';

import '../core/narrative/ending.dart';
import '../core/narrative/story_choice.dart';
import 'codex_screen.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'inventory_screen.dart';
import 'widgets/atmosphere.dart';
import 'widgets/choice_button.dart';
import 'widgets/confirm_sheet.dart';
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

  /// Which world this screen is meant to show. Used both to start a session
  /// when the controller hasn't been given one yet, and to detect a stale
  /// one: a curated world's [ChargenScreen] starts the session itself (with
  /// the player's chargen input) before navigating here, so in that case
  /// this screen must not re-`start()` and discard it — but
  /// [WorldSelectScreen] can also navigate straight here (skipping chargen)
  /// for a world that already has a persisted session, and if the
  /// controller is still holding a *different* world from an earlier story,
  /// leaving it in place would silently show that other story instead.
  final String worldSlug;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _freeAction = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _lastNarration = '';

  /// Whether the full choices bar is showing. On mobile, a reader can blow
  /// past the prose to the buttons at the bottom without ever reading it —
  /// so each new turn starts with choices hidden behind a "keep reading"
  /// hint, and stays hidden (and then stays revealed, no re-hiding on
  /// scrolling back up) once set. Short text that doesn't overflow the
  /// viewport at all reveals immediately — there's nothing to scroll
  /// through.
  bool _choicesRevealed = false;

  /// Whether the player has scrolled through the whole turn and the hint can
  /// turn into a tappable "ver opciones" button. Deliberately does **not**
  /// auto-reveal [_choicesRevealed] on its own: the choices bar is taller
  /// than the hint, and swapping it in the instant the scroll position
  /// crossed a threshold used to cover the last lines of text the player was
  /// still reading, mid-scroll — now that swap only happens on an explicit
  /// tap, once the player has actually finished and chooses to see options.
  bool _canRevealChoices = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _scroll.addListener(_onScroll);
    if (!widget.controller.isReady || widget.controller.world?.slug != widget.worldSlug) {
      widget.controller.start(widget.worldSlug);
    } else {
      // ChargenScreen already called start() and handed us a ready
      // controller — its notifyListeners() for that first turn fired before
      // this State existed to hear it, so _onControllerChange never runs for
      // it. Arm the reveal gate for whatever's already loaded instead of
      // leaving it permanently gated behind a turn change that already
      // happened (campaign-bible bug: short opening prose that fits without
      // scrolling never revealed the choices bar at all).
      _lastNarration = widget.controller.narration;
      WidgetsBinding.instance.addPostFrameCallback((_) => _armRevealGate());
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
      setState(() {
        _choicesRevealed = false;
        _canRevealChoices = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(0,
            duration: AetherMotion.slow, curve: AetherMotion.standard);
        _armRevealGate();
      });
    }
  }

  /// Reveals the choices immediately when the current narration doesn't
  /// overflow the viewport — there's nothing to scroll through, so gating
  /// on a scroll gesture that can never happen would strand the player.
  void _armRevealGate() {
    if (!_scroll.hasClients || !mounted) return;
    if (_scroll.position.maxScrollExtent <= 0) {
      setState(() => _choicesRevealed = true);
    }
  }

  void _onScroll() {
    if (_canRevealChoices || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 24) {
      setState(() => _canRevealChoices = true);
    }
  }

  void _revealChoices() => setState(() => _choicesRevealed = true);

  void _submitFreeAction() {
    final text = _freeAction.text.trim();
    if (text.isEmpty) return;
    _freeAction.clear();
    FocusScope.of(context).unfocus();
    widget.controller.choose(text);
  }

  void _goToMenu() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        pageBuilder: (_, _, _) => WorldSelectScreen(controller: widget.controller),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: AetherBackground(
        particles: false,
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
                      onOpenInventory: () => Navigator.of(context).push(
                        InventoryScreen.route(
                            world: c.world!, character: c.character!),
                      ),
                      onBack: _goToMenu,
                    ),
                    Expanded(
                      child: _NarrationView(controller: c, scroll: _scroll),
                    ),
                    if (c.isLoading || _choicesRevealed)
                      _ChoicesBar(
                        controller: c,
                        freeAction: _freeAction,
                        onSubmitFree: _submitFreeAction,
                        onFinishStory: _goToMenu,
                      )
                    else
                      _KeepReadingHint(
                        ready: _canRevealChoices,
                        onReveal: _revealChoices,
                      ),
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
          _SceneImage(controller: controller),
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

/// The scene illustration for the current turn (GDD §6) — optional and
/// asynchronous, never blocks reading: narration and choices already work
/// with it absent. While [GameController.imageLoading] is true, shows a
/// quiet shimmer placeholder; once [GameController.imageUrl] arrives, it
/// fades in the same way the narration text itself does. Renders nothing at
/// all (no reserved space) when there's neither — no generator configured,
/// this world never calls the narrator, or generation failed — so a plain
/// curated/AI-free campaign's screen looks exactly as it always has.
class _SceneImage extends StatelessWidget {
  const _SceneImage({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final imageUrl = controller.imageUrl;
    final loading = controller.imageLoading;
    if (imageUrl == null && !loading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AetherSpace.xl),
      child: ClipRRect(
        borderRadius: AetherRadius.allLg,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: AnimatedSwitcher(
            duration: AetherMotion.slow,
            switchInCurve: AetherMotion.standard,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    key: ValueKey(imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  )
                : const _SceneImageShimmer(key: ValueKey('scene-image-shimmer')),
          ),
        ),
      ),
    );
  }
}

/// A soft, looping pulse between two surface tones — "la imagen se está
/// dibujando", without borrowing any loading-spinner iconography that would
/// compete with [DestinyWriting]'s own "el destino se escribe…" indicator.
class _SceneImageShimmer extends StatefulWidget {
  const _SceneImageShimmer({super.key});

  @override
  State<_SceneImageShimmer> createState() => _SceneImageShimmerState();
}

class _SceneImageShimmerState extends State<_SceneImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ColoredBox(
        color: Color.lerp(
          AetherColors.surface,
          AetherColors.surfaceRaised,
          _controller.value,
        )!,
      ),
    );
  }
}

/// Sits where the choice buttons would be once the epilogue's the last
/// thing left to read — the graph has nowhere further to go, so this is an
/// explicit "you're done" instead of a silently empty choices bar.
class _EndOfStory extends StatelessWidget {
  const _EndOfStory({
    required this.onFinishStory,
    this.endingOrdinal,
    this.endingsTotal,
  });

  final VoidCallback onFinishStory;

  /// This ending's 1-based position among the campaign's declared endings,
  /// and how many it declares in total — both `null` for a curated, AI-free
  /// story's dead end (no `ResolutionNode.endings` mechanic at all) or a
  /// hybrid campaign's pure epilogue node with no endings of its own. V2
  /// design prototype §1b: "Final descubierto · N de M".
  final int? endingOrdinal;
  final int? endingsTotal;

  @override
  Widget build(BuildContext context) {
    final ordinal = endingOrdinal;
    final total = endingsTotal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ordinal != null && total != null) ...[
          Text('Final descubierto · $ordinal de $total',
              style: AetherType.caption.copyWith(color: AetherColors.parchmentFaint)),
          const SizedBox(height: AetherSpace.sm),
        ],
        Text('Fin de la historia',
            style: AetherType.overline.copyWith(color: AetherColors.goldSoft)),
        const SizedBox(height: AetherSpace.md),
        ChoiceButton(label: 'Volver al menú', onTap: onFinishStory),
      ],
    );
  }
}

/// Sits where [_ChoicesBar] would, before the player has finished reading
/// the current turn's prose. Two states: a quiet, non-interactive nudge
/// while there's still text below the fold ([ready] false), and — once the
/// player has scrolled all the way down — a real tappable button that reveals
/// the choices bar on an explicit tap rather than automatically. That's
/// deliberate: the choices bar is taller than this hint, so auto-revealing
/// it the instant the scroll position crossed a threshold used to cover the
/// last lines of text the player was still reading, mid-scroll.
class _KeepReadingHint extends StatefulWidget {
  const _KeepReadingHint({required this.ready, required this.onReveal});

  final bool ready;
  final VoidCallback onReveal;

  @override
  State<_KeepReadingHint> createState() => _KeepReadingHintState();
}

class _KeepReadingHintState extends State<_KeepReadingHint> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.ready;
    final accent = ready ? AetherColors.goldSoft : AetherColors.parchmentFaint;
    return GestureDetector(
      onTapDown: ready ? (_) => _set(true) : null,
      onTapUp: ready ? (_) => _set(false) : null,
      onTapCancel: ready ? () => _set(false) : null,
      onTap: ready ? widget.onReveal : null,
      child: AnimatedContainer(
        duration: AetherMotion.fast,
        padding: const EdgeInsets.symmetric(
            horizontal: AetherSpace.lg, vertical: AetherSpace.lg),
        decoration: BoxDecoration(
          color: ready && _pressed ? AetherColors.surfaceRaised : AetherColors.surface,
          border: const Border(top: BorderSide(color: AetherColors.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ready ? 'Ver opciones' : 'Sigue leyendo',
                style: AetherType.caption.copyWith(
                  color: accent,
                  fontWeight: ready ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: AetherSpace.xs),
              Icon(
                ready ? Icons.chevron_right_rounded : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: accent,
              ),
            ],
          ),
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
    required this.onFinishStory,
  });

  final GameController controller;
  final TextEditingController freeAction;
  final VoidCallback onSubmitFree;

  /// Takes the player back to the story menu — used both when there's
  /// nothing left to do at all (an unreachable dead end, shouldn't happen)
  /// and, deliberately, as the only affordance once the epilogue is reached.
  final VoidCallback onFinishStory;

  /// Resolves a tapped [StoryChoice], first asking for confirmation when it's
  /// marked irreversible (campaign-bible §20.3/§26.4) — a curated author's
  /// `confirmation_text`, or a generic fallback if the choice declares none.
  Future<void> _tapStoryChoice(BuildContext context, StoryChoice choice) async {
    if (!choice.requiresConfirmation) {
      controller.chooseStoryChoice(choice);
      return;
    }
    final confirmed = await showConfirmSheet(
      context,
      title: choice.label,
      message:
          choice.confirmationText ?? 'No se puede deshacer. ¿Confirmas esta decisión?',
      confirmLabel: 'Confirmar',
    );
    if (confirmed) {
      controller.chooseStoryChoice(choice);
    }
  }

  /// Resolves a tapped climax [Ending] — always with confirmation. Unlike
  /// `StoryChoice`, `Ending` declares no `requiresConfirmation` of its own:
  /// every ending is the campaign's climax by definition, so the UI treats
  /// all of them as irreversible rather than asking content to say so once
  /// per ending.
  Future<void> _tapEnding(BuildContext context, Ending ending) async {
    final confirmed = await showConfirmSheet(
      context,
      title: ending.visibleChoice,
      message: 'Esta es una decisión final — no hay vuelta atrás.',
      confirmLabel: 'Confirmar',
    );
    if (confirmed) {
      controller.chooseEnding(ending);
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
    // The graph's true dead end: a curated node with nothing left to tap —
    // both campaigns' epilogues land here (the hybrid one's `ResolutionNode`
    // with no `endings` of its own, and the AI-free campaign's closing
    // `FixedAnchorNode` with an empty `choices` list). Free text is
    // suppressed here too, regardless of `allowFreeText` — there's nothing
    // left in the graph for a typed action to resolve against.
    final atEpilogue = curated &&
        controller.availableStoryChoices.isEmpty &&
        controller.availableActivities.isEmpty &&
        controller.availableEndings.isEmpty;
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
              : atEpilogue
                  ? _EndOfStory(
                      onFinishStory: onFinishStory,
                      endingOrdinal: controller.achievedEndingOrdinal,
                      endingsTotal: controller.achievedEndingsTotal,
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
                                      padding: const EdgeInsets.only(
                                          bottom: AetherSpace.md),
                                      child: ChoiceButton(
                                        label: choice.label,
                                        onTap: () => _tapStoryChoice(context, choice),
                                      ),
                                    ),
                                  for (final activity in controller.availableActivities)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AetherSpace.md),
                                      child: ChoiceButton(
                                        label: activity.label,
                                        onTap: () =>
                                            controller.chooseHubActivity(activity),
                                      ),
                                    ),
                                  for (final ending in controller.availableEndings)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AetherSpace.md),
                                      child: ChoiceButton(
                                        label: ending.visibleChoice,
                                        onTap: () => _tapEnding(context, ending),
                                      ),
                                    ),
                                ] else if (controller.choices.isNotEmpty)
                                  for (final choice in controller.choices)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AetherSpace.md),
                                      child: ChoiceButton(
                                        label: choice,
                                        onTap: () => controller.choose(choice),
                                      ),
                                    )
                                else
                                  // The AI didn't return any suggested_choices
                                  // this turn (a legitimate outcome — not
                                  // every turn needs a decision point). Free
                                  // text stays available below regardless;
                                  // this just lets the story keep moving
                                  // without forcing one.
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AetherSpace.md),
                                    child: ChoiceButton(
                                      label: 'Continuar',
                                      onTap: controller.continueStory,
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
