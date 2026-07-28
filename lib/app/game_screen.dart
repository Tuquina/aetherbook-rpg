import 'package:flutter/material.dart';

import '../core/narrative/ending.dart';
import '../core/narrative/story_choice.dart';
import 'character_sheet_sheet.dart';
import 'codex_screen.dart';
import 'design/breakpoints.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'design/world_theme.dart';
import 'game_controller.dart';
import 'inventory_screen.dart';
import 'widgets/atmosphere.dart';
import 'widgets/choice_button.dart';
import 'widgets/choice_card.dart';
import 'widgets/confirm_sheet.dart';
import 'widgets/fate_roll.dart';
import 'widgets/status_bar.dart';
import 'widgets/story_menu_sheet.dart';
import 'widgets/vow_status.dart';
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

  /// 0 (top of the turn) to 1 (scrolled past [_headerCollapseDistance]) —
  /// drives [StatusBar.collapse] directly off the scroll offset, no separate
  /// animation clock (V2 design prototype §1a's two-state header). Reset to
  /// 0 whenever a new turn scrolls back to the top.
  double _headerCollapse = 0.0;

  static const double _headerCollapseDistance = 90.0;

  /// The [Ending] just confirmed via `_ChoicesBar.onEndingChosen`, still
  /// awaiting its `_EndingRevealOverlay` (V2 §1b) — cleared once the player
  /// taps "Leer el epílogo". `null` means no overlay is showing.
  Ending? _pendingEnding;

  /// Which `achievedEndingOrdinal` has already had its overlay shown and
  /// dismissed, so `_onControllerChange` doesn't re-trigger it on later
  /// rebuilds (the controller's ending state stays set for the rest of the
  /// session, unlike `_lastNarration`).
  int? _endingRevealedFor;

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
        _headerCollapse = 0.0;
      });
      final ordinal = widget.controller.achievedEndingOrdinal;
      if (ordinal != null && ordinal != _endingRevealedFor) {
        // The epilogue narration just arrived, but the reader hasn't seen
        // "final descubierto" yet — `_dismissEndingReveal` does the
        // scroll-to-top once the overlay is closed instead of here.
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(0,
            duration: AetherMotion.slow, curve: AetherMotion.standard);
        _armRevealGate();
      });
    }
  }

  void _onEndingChosen(Ending ending) => setState(() => _pendingEnding = ending);

  /// Closes `_EndingRevealOverlay` and reveals the epilogue text underneath
  /// (already fully resolved by `GameController.chooseEnding` — this is
  /// purely a UI dismissal, no new async work).
  void _dismissEndingReveal() {
    setState(() {
      _endingRevealedFor = widget.controller.achievedEndingOrdinal;
      _pendingEnding = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(0, duration: AetherMotion.slow, curve: AetherMotion.standard);
      _armRevealGate();
    });
  }

  /// Reveals the choices immediately when the current narration doesn't
  /// overflow the viewport — there's nothing to scroll through, so gating
  /// on a scroll gesture that can never happen would strand the player.
  ///
  /// Called from more than one place on purpose: a single check right after
  /// the turn changes used to be enough in theory, but for a turn whose
  /// content lands right at the edge of the viewport height, the scrollable
  /// can still be settling into its final `maxScrollExtent` on that first
  /// check — reading a stale, still-nonzero value, deciding not to reveal,
  /// and then never getting another chance: with nothing to scroll,
  /// `_onScroll` (which only fires on an actual `pixels` change) never runs
  /// either, permanently stranding the choices behind the hint. The
  /// `NotificationListener<ScrollMetricsNotification>` around the narration
  /// view re-runs this on every metrics update — including ones with no
  /// scroll gesture behind them — so it keeps checking until the extent
  /// actually settles, instead of gambling on a single frame.
  void _armRevealGate() {
    if (_choicesRevealed || !_scroll.hasClients || !mounted) return;
    if (_scroll.position.maxScrollExtent <= 0) {
      setState(() => _choicesRevealed = true);
    }
  }

  bool _onScrollMetricsChanged(ScrollMetricsNotification notification) {
    _armRevealGate();
    return false;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final collapse =
        (position.pixels / _headerCollapseDistance).clamp(0.0, 1.0);
    if (collapse != _headerCollapse) {
      setState(() => _headerCollapse = collapse);
    }
    if (_canRevealChoices) return;
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

  /// Opens the story-menu sheet (V2 Stage 5) — the back arrow no longer
  /// leaves the story on a single tap; it offers to keep reading, go back to
  /// the library, or abandon this story outright.
  void _openStoryMenu() {
    showStoryMenuSheet(
      context,
      onBackToLibrary: _goToMenu,
      onAbandon: _abandonActiveStory,
    );
  }

  /// Confirms, then abandons the session currently in progress — reachable
  /// from inside the story itself (unlike `WorldSelectScreen`'s abandon,
  /// which operates on a `GameSessionSummary` from a list). Always leaves
  /// for the library afterward: there's nothing left on this screen once the
  /// session is gone.
  Future<void> _abandonActiveStory() async {
    final confirmed = await showConfirmSheet(
      context,
      title: '¿Abandonar esta historia?',
      message: 'Se borra tu progreso en esta historia. No se puede deshacer.',
      confirmLabel: 'Abandonar',
    );
    if (!confirmed) return;
    await widget.controller.abandonActiveSession();
    if (!mounted) return;
    _goToMenu();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    // `null` only while `start()` hasn't resolved a world yet (loading/error
    // states below) — `AetherBackground`'s own defaults (gold/ink) apply then.
    final theme = c.world != null ? WorldTheme.forWorld(c.world!) : null;
    return Scaffold(
      body: AetherBackground(
        particles: false,
        accent: theme?.accent ?? AetherColors.gold,
        base: theme?.base ?? AetherColors.ink,
        texture: theme?.texture,
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
            final pendingEnding = _pendingEnding;
            return Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= AetherBreakpoints.tablet;
                    return _ReadingFrame(
                      wide: wide,
                      child: SafeArea(
                        child: wide
                            ? _SplitView(
                                controller: c,
                                theme: theme!,
                                scroll: _scroll,
                                freeAction: _freeAction,
                                onSubmitFree: _submitFreeAction,
                                onFinishStory: _goToMenu,
                                onEndingChosen: _onEndingChosen,
                                onBack: _openStoryMenu,
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  StatusBar(
                                    world: c.world!,
                                    character: c.character!,
                                    onOpenCodex: () => Navigator.of(context).push(
                                        CodexScreen.route(world: c.world!, character: c.character!)),
                                    onOpenInventory: () => showInventorySheet(context,
                                        world: c.world!, character: c.character!),
                                    onOpenCharacterSheet: () => showCharacterSheet(context,
                                        world: c.world!,
                                        character: c.character!,
                                        turnCount: c.turnCount),
                                    onBack: _openStoryMenu,
                                    collapse: _headerCollapse,
                                  ),
                                  Expanded(
                                    child: NotificationListener<ScrollMetricsNotification>(
                                      onNotification: _onScrollMetricsChanged,
                                      child: _NarrationView(controller: c, scroll: _scroll),
                                    ),
                                  ),
                                  if (c.isLoading || _choicesRevealed)
                                    _ChoicesBar(
                                      controller: c,
                                      freeAction: _freeAction,
                                      onSubmitFree: _submitFreeAction,
                                      onFinishStory: _goToMenu,
                                      onEndingChosen: _onEndingChosen,
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
                if (pendingEnding != null)
                  _EndingRevealOverlay(
                    ending: pendingEnding,
                    ordinal: c.achievedEndingOrdinal!,
                    total: c.achievedEndingsTotal!,
                    turnCount: c.turnCount,
                    level: c.character!.level,
                    vowText: c.character!.vowId == null
                        ? null
                        : c.world!.vowByIdOrNull(c.character!.vowId)?.text,
                    vowStatus: c.character!.varValue('vow_status'),
                    vowTestedCount: c.character!.meter('vow_tested_count'),
                    onDismiss: _dismissEndingReveal,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Keeps the game a comfortable reading width on any screen. Below
/// [AetherBreakpoints.tablet] it's edge-to-edge as designed (mobile,
/// unaffected by [wide]); at or above it, [wide] tells it which layout is
/// inside ([_SplitView] instead of the mobile column, V2 §1c) and therefore
/// how wide a "codex page" to frame it at once the viewport outgrows even
/// that — so it reads like an open tome instead of stretching across the
/// whole window, same idea as before, just two different frame widths for
/// two different children.
class _ReadingFrame extends StatelessWidget {
  const _ReadingFrame({required this.child, required this.wide});

  final Widget child;
  final bool wide;

  static const double _mobileMaxWidth = 720;
  static const double _wideMaxWidth = 1040;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = wide ? _wideMaxWidth : _mobileMaxWidth;
    if (width <= maxWidth) return child;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AetherSpace.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
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
  const _NarrationView({
    required this.controller,
    required this.scroll,
    this.showSceneImage = true,
  });

  final GameController controller;
  final ScrollController scroll;

  /// `false` in [_SplitView] (V2 §1c): the scene already renders in
  /// `_ScenePanel`, to the left, so showing it again here would duplicate it.
  final bool showSceneImage;

  @override
  Widget build(BuildContext context) {
    final resolution = controller.lastResolution;
    return SingleChildScrollView(
      key: const Key('narrationScroll'),
      controller: scroll,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Edge-to-edge, unpadded — the scene "opens" the turn the way the
          // V2 prototype's §1a hero art does, fading under the reading
          // column via its own bottom gradient rather than sitting inside a
          // bordered card. Renders nothing when there's no image (curated/
          // AI-free worlds, or generation still pending with none loaded).
          if (showSceneImage) _SceneImage(controller: controller),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AetherSpace.xl, AetherSpace.xl, AetherSpace.xl, AetherSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (resolution != null) ...[
                  // "Mostrar la tirada" off (V2 §6b): the outcome still
                  // narrates normally, it just never renders the dice-check
                  // widget itself.
                  if (controller.settings.showTheRoll)
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
                AnimatedOpacity(
                  duration: AetherMotion.base,
                  // The last successful narration dims while a fresh attempt
                  // is failing (V2 §1b) — a quiet "this is stale" cue; the
                  // actual error surfaces in `_NarratorErrorPanel`, not here.
                  opacity: controller.error != null ? 0.4 : 1,
                  child: AnimatedSwitcher(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The web/tablet layout (V2 design prototype §1c): a fixed scene panel to
/// the left, the reading column to the right — the same content
/// (`StatusBar`, roll, prose, choices) `GameScreen`'s mobile column always
/// had, just laid out side by side instead of stacked, with the header
/// pinned (`collapse: 0`, always expanded) and the choices bar always
/// visible instead of gated behind `_KeepReadingHint` — there's plenty of
/// vertical room, and the mockup doesn't scroll-gate here either.
class _SplitView extends StatelessWidget {
  const _SplitView({
    required this.controller,
    required this.theme,
    required this.scroll,
    required this.freeAction,
    required this.onSubmitFree,
    required this.onFinishStory,
    required this.onEndingChosen,
    required this.onBack,
  });

  final GameController controller;
  final WorldTheme theme;
  final ScrollController scroll;
  final TextEditingController freeAction;
  final VoidCallback onSubmitFree;
  final VoidCallback onFinishStory;
  final ValueChanged<Ending> onEndingChosen;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 4, child: _ScenePanel(controller: controller, theme: theme)),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusBar(
                world: controller.world!,
                character: controller.character!,
                onOpenCodex: () => Navigator.of(context).push(CodexScreen.route(
                    world: controller.world!, character: controller.character!)),
                onOpenInventory: () => showInventorySheet(context,
                    world: controller.world!, character: controller.character!),
                onOpenCharacterSheet: () => showCharacterSheet(context,
                    world: controller.world!,
                    character: controller.character!,
                    turnCount: controller.turnCount),
                onBack: onBack,
                collapse: 0,
              ),
              Expanded(
                child: _NarrationView(
                    controller: controller, scroll: scroll, showSceneImage: false),
              ),
              _ChoicesBar(
                controller: controller,
                freeAction: freeAction,
                onSubmitFree: onSubmitFree,
                onFinishStory: onFinishStory,
                onEndingChosen: onEndingChosen,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The left-hand scene panel in [_SplitView] — unlike [_SceneImage] (which
/// collapses to nothing when there's no image, appropriate for a stacked
/// mobile column), this always occupies its full column, falling back to
/// the world's own theme tint when there's no illustration to show.
class _ScenePanel extends StatelessWidget {
  const _ScenePanel({required this.controller, required this.theme});

  final GameController controller;
  final WorldTheme theme;

  @override
  Widget build(BuildContext context) {
    final imageUrl = controller.imageUrl;
    final loading = controller.imageLoading;
    return ColoredBox(
      color: theme.base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            AnimatedSwitcher(
              duration: AetherMotion.slow,
              switchInCurve: AetherMotion.standard,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Image.network(
                imageUrl,
                key: ValueKey(imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            )
          else if (loading)
            const _SceneImageShimmer(key: ValueKey('scene-panel-shimmer')),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, theme.base.withValues(alpha: 0.85)],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: AetherSpace.lg,
            right: AetherSpace.lg,
            bottom: AetherSpace.lg,
            child: Text(
              controller.world!.name.toUpperCase(),
              style: AetherType.overline.copyWith(color: theme.accent),
            ),
          ),
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

  static const double _height = 260;

  @override
  Widget build(BuildContext context) {
    final imageUrl = controller.imageUrl;
    final loading = controller.imageLoading;
    if (imageUrl == null && !loading) return const SizedBox.shrink();

    return SizedBox(
      height: _height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
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
          // The bleed: the scene dissolves into the reading background
          // instead of stopping at a hard card edge (V2 prototype §1a).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00151210),
                  Color(0xCC15120F),
                  AetherColors.ink,
                ],
                stops: [0.0, 0.75, 1.0],
              ),
            ),
          ),
        ],
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
    // Respect the OS "reduce motion" preference (V2 Stage 8), same pattern
    // as `AetherBackground`/`DestinyWriting`.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _controller.isAnimating) _controller.stop();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ColoredBox(
        color: Color.lerp(
          AetherColors.surface,
          AetherColors.surfaceRaised,
          reduceMotion ? 0.5 : _controller.value,
        )!,
      ),
    );
  }
}

/// Sits where the choice buttons would be while `controller.error != null`
/// (V2 design prototype §1b) — the last attempt failed before anything
/// committed (see `GameController._resolveTurn`'s catch block), so this
/// always shows a fixed, reassuring message rather than the raw exception
/// text `controller.error` carries, which is meant for logs/debugging, not
/// the player. [attemptCount] (V2 Stage 7) surfaces how many distinct
/// providers the Edge Function actually tried before giving up — real data
/// parsed off the wire (`NarratorHttpException.attemptCount`), not the
/// mockup's live auto-retry countdown ("Intento 2 de 3 · reintentando en
/// 8 s"): by the time this panel shows, every configured provider has
/// already failed, so there's no in-progress countdown to display honestly
/// — "Reintentar" simply re-runs the exact same last action on tap, same as
/// before. `null` whenever the failure carries no such detail (a plain
/// network error, or a curated world's own resolution error, which never
/// touches the narrator at all) — the line is omitted entirely then.
class _NarratorErrorPanel extends StatelessWidget {
  const _NarratorErrorPanel({
    required this.onRetry,
    required this.onChooseAgain,
    this.attemptCount,
  });

  final VoidCallback onRetry;
  final VoidCallback onChooseAgain;
  final int? attemptCount;

  @override
  Widget build(BuildContext context) {
    final count = attemptCount;
    return Container(
      padding: const EdgeInsets.all(AetherSpace.lg),
      decoration: BoxDecoration(
        color: AetherColors.failure.withValues(alpha: 0.07),
        borderRadius: AetherRadius.allLg,
        border: Border.all(color: AetherColors.failure.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AetherColors.failure, size: 20),
              const SizedBox(width: AetherSpace.sm),
              Text('EL NARRADOR NO RESPONDE',
                  style: AetherType.overline.copyWith(color: AetherColors.failure)),
            ],
          ),
          const SizedBox(height: AetherSpace.md),
          Text(
            'Tu decisión quedó guardada — nada se perdió. El mundo tarda en '
            'contestar; puede ser la conexión.',
            style: AetherType.body,
          ),
          if (count != null) ...[
            const SizedBox(height: AetherSpace.sm),
            Text(
              count == 1
                  ? 'Lo intentamos una vez, sin éxito.'
                  : 'Lo intentamos $count veces, con fuentes distintas, sin éxito.',
              style: AetherType.caption.copyWith(color: AetherColors.parchmentDim),
            ),
          ],
          const SizedBox(height: AetherSpace.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AetherColors.gold.withValues(alpha: 0.16),
                    side: BorderSide(color: AetherColors.gold.withValues(alpha: 0.6)),
                    foregroundColor: AetherColors.goldBright,
                    padding: const EdgeInsets.symmetric(vertical: AetherSpace.md),
                    shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 18),
                      const SizedBox(width: AetherSpace.xs),
                      Text('Reintentar',
                          style: AetherType.label.copyWith(color: AetherColors.goldBright)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AetherSpace.sm),
              OutlinedButton(
                onPressed: onChooseAgain,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AetherColors.hairlineStrong),
                  foregroundColor: AetherColors.parchmentDim,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AetherSpace.md, vertical: AetherSpace.md),
                  shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
                ),
                child: Text('Elegir otra vez', style: AetherType.label),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-screen "final descubierto" interstitial (V2 design prototype §1b),
/// shown once between confirming an [Ending] and reading its epilogue —
/// `GameController.chooseEnding` already resolved and narrated everything by
/// the time this appears, so dismissing it is purely a UI reveal, not a new
/// action. Deliberately the *lightweight* version confirmed for this pass:
/// there's no separate ending title/summary-quote content field on [Ending]
/// today, so the headline reuses [Ending.visibleChoice] (the option text the
/// player tapped) instead of inventing new authored copy across 3 worlds'
/// worth of endings.
class _EndingRevealOverlay extends StatelessWidget {
  const _EndingRevealOverlay({
    required this.ending,
    required this.ordinal,
    required this.total,
    required this.turnCount,
    required this.level,
    required this.vowText,
    required this.vowStatus,
    required this.vowTestedCount,
    required this.onDismiss,
  });

  final Ending ending;
  final int ordinal;
  final int total;
  final int turnCount;
  final int level;

  /// `null` when the character has no `vowId` at all — the juramento row is
  /// only shown when there's an actual vow to report on.
  final String? vowText;
  final String? vowStatus;
  final int vowTestedCount;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AetherColors.void_.withValues(alpha: 0.86),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AetherSpace.xl),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(AetherSpace.xl),
                decoration: BoxDecoration(
                  color: AetherColors.surfaceRaised,
                  borderRadius: AetherRadius.allLg,
                  border: Border.all(color: AetherColors.gold.withValues(alpha: 0.4)),
                  boxShadow: AetherShadow.panel,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('FINAL DESCUBIERTO · $ordinal DE $total',
                        style: AetherType.overline.copyWith(color: AetherColors.gold)),
                    const SizedBox(height: AetherSpace.md),
                    Text(
                      ending.visibleChoice,
                      style: AetherType.display.copyWith(fontSize: 26),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AetherSpace.xl),
                    Row(
                      children: [
                        Expanded(
                          child: _EndingStat(label: 'Turnos', value: '$turnCount'),
                        ),
                        const SizedBox(width: AetherSpace.sm),
                        Expanded(
                          child: _EndingStat(label: 'Nivel final', value: '$level'),
                        ),
                      ],
                    ),
                    if (vowText != null) ...[
                      const SizedBox(height: AetherSpace.sm),
                      _EndingVowStat(
                        vowText: vowText!,
                        status: vowStatus,
                        testedCount: vowTestedCount,
                      ),
                    ],
                    const SizedBox(height: AetherSpace.xl),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onDismiss,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AetherColors.gold,
                          foregroundColor: AetherColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: AetherSpace.md),
                          shape: RoundedRectangleBorder(borderRadius: AetherRadius.allMd),
                        ),
                        child: Text('Leer el epílogo',
                            style: AetherType.label.copyWith(color: AetherColors.ink)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EndingStat extends StatelessWidget {
  const _EndingStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm),
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AetherType.overline.copyWith(color: AetherColors.parchmentFaint, fontSize: 9)),
          const SizedBox(height: 4),
          Text(value, style: AetherType.title.copyWith(fontSize: 19)),
        ],
      ),
    );
  }
}

/// Same wording as `ProfileScreen`'s `_VowCard`, reused verbatim so a vow's
/// status reads identically whether the player sees it here or on Perfil.
class _EndingVowStat extends StatelessWidget {
  const _EndingVowStat({
    required this.vowText,
    required this.status,
    required this.testedCount,
  });

  final String vowText;
  final String? status;
  final int testedCount;

  @override
  Widget build(BuildContext context) {
    final (:color, :icon, :label) = resolveVowStatus(status, testedCount);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AetherSpace.md),
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TU JURAMENTO',
              style: AetherType.overline.copyWith(color: AetherColors.parchmentFaint, fontSize: 9)),
          const SizedBox(height: 6),
          Text('«$vowText»',
              style: AetherType.body.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(label, style: AetherType.caption.copyWith(color: color)),
            ],
          ),
        ],
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
    required this.onEndingChosen,
  });

  final GameController controller;
  final TextEditingController freeAction;
  final VoidCallback onSubmitFree;

  /// Takes the player back to the story menu — used both when there's
  /// nothing left to do at all (an unreachable dead end, shouldn't happen)
  /// and, deliberately, as the only affordance once the epilogue is reached.
  final VoidCallback onFinishStory;

  /// Tells `_GameScreenState` which [Ending] was just confirmed, so it can
  /// show `_EndingRevealOverlay` once `controller.chooseEnding` finishes and
  /// the epilogue narration arrives (V2 §1b) — `achievedEndingOrdinal` alone
  /// is just an index, not the `Ending` itself.
  final ValueChanged<Ending> onEndingChosen;

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
      onEndingChosen(ending);
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
    // Roman-numeral position runs across every source in "Tu decisión" as one
    // sequence (story choices, then hub activities, then endings) rather than
    // restarting at I per source — the player reads them as a single list
    // (V2 design prototype §1a's numbered `ChoiceCard`s).
    var choiceIndex = 0;
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
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AetherSpace.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DestinyWriting(),
                      const SizedBox(height: AetherSpace.sm),
                      Text(
                        'Puedes seguir leyendo el turno anterior',
                        style: AetherType.caption.copyWith(color: AetherColors.parchmentFaint),
                      ),
                    ],
                  ),
                )
              : controller.error != null
                  ? _NarratorErrorPanel(
                      onRetry: controller.retryLastAction,
                      onChooseAgain: controller.clearError,
                      attemptCount: controller.narratorAttemptCount,
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
                                      child: ChoiceCard(
                                        index: ++choiceIndex,
                                        label: choice.label,
                                        onTap: () => _tapStoryChoice(context, choice),
                                      ),
                                    ),
                                  for (final activity in controller.availableActivities)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AetherSpace.md),
                                      child: ChoiceCard(
                                        index: ++choiceIndex,
                                        label: activity.label,
                                        onTap: () =>
                                            controller.chooseHubActivity(activity),
                                      ),
                                    ),
                                  for (final ending in controller.availableEndings)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AetherSpace.md),
                                      child: ChoiceCard(
                                        index: ++choiceIndex,
                                        label: ending.visibleChoice,
                                        onTap: () => _tapEnding(context, ending),
                                      ),
                                    ),
                                ] else if (controller.choices.isNotEmpty)
                                  for (final choice in controller.choices)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AetherSpace.md),
                                      child: ChoiceCard(
                                        index: ++choiceIndex,
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
