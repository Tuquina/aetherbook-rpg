import 'package:flutter/material.dart';

import 'codex_screen.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'widgets/atmosphere.dart';
import 'widgets/choice_button.dart';
import 'widgets/fate_roll.dart';
import 'widgets/status_bar.dart';

/// The single play screen: an atmospheric backdrop, the status bar up top, the
/// narration (with the Fate Roll reveal) in the middle, and the choices at the
/// foot (GDD §9). Rebuilds from the [GameController] via [ListenableBuilder] —
/// no extra state-mgmt package.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _freeAction = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _lastNarration = '';

  @override
  void initState() {
    super.initState();
    widget.controller
      ..addListener(_onControllerChange)
      ..start('xianxia');
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _freeAction.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Scroll the narration back to the top when a new turn arrives, so the
  /// Fate Roll and fresh prose are in view.
  void _onControllerChange() {
    final narration = widget.controller.narration;
    if (narration != _lastNarration) {
      _lastNarration = narration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(0,
              duration: AetherMotion.slow, curve: AetherMotion.standard);
        }
      });
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
                    ),
                    Expanded(
                      child: _NarrationView(controller: c, scroll: _scroll),
                    ),
                    _ChoicesBar(
                      controller: c,
                      freeAction: _freeAction,
                      onSubmitFree: _submitFreeAction,
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
          child: busy
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AetherSpace.lg),
                  child: DestinyWriting(),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final choice in controller.choices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AetherSpace.md),
                        child: ChoiceButton(
                          label: choice,
                          onTap: () => controller.choose(choice),
                        ),
                      ),
                    const SizedBox(height: AetherSpace.xs),
                    FreeActionField(
                        controller: freeAction, onSubmit: onSubmitFree),
                  ],
                ),
        ),
      ),
    );
  }
}
