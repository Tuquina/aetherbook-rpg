import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ports/auth_port.dart';
import 'account_screen.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'onboarding_screen.dart';
import 'widgets/atmosphere.dart';
import 'widgets/brand_mark.dart';
import 'world_select_screen.dart';

/// The entry screen: the brand symbol, the wordmark, and the way in. A moment
/// of arrival before the world opens (GDD §9). "Comenzar" leads to
/// [WorldSelectScreen] once the player has a real account — there is no
/// anonymous/guest path anymore: without one, "Comenzar" routes to
/// [AccountScreen] first (sign up or sign in, Google or email+password), and
/// only continues on to [WorldSelectScreen] once that succeeds.
///
/// V2 (design prototype §10a): the old animated tome painter is replaced by
/// [BrandMark] (the same symbol every other screen uses), and three short
/// lines now say what this actually is before "Comenzar" — there was no such
/// explanation before this.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.controller, this.auth});

  final GameController controller;

  /// `null` when Supabase failed to initialize (degraded, in-memory-only
  /// mode) — there's no account system to gate on in that case, so
  /// "Comenzar" plays in-memory rather than stranding the player behind a
  /// login screen that can't actually work.
  final AuthPort? auth;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  bool _checkingOnboarding = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// The one entry action: goes straight to [WorldSelectScreen] once there's
  /// a real account (or in the degraded in-memory-only mode, where there's
  /// no account system to gate on at all) — otherwise routes to
  /// [AccountScreen] first, since there's no anonymous/guest path anymore.
  void _begin() {
    final auth = widget.auth;
    if (auth != null && auth.isAnonymous) {
      Navigator.of(context).push(
        AccountScreen.route(authPort: auth, onAuthenticated: _afterAuth),
      );
    } else {
      _afterAuth();
    }
  }

  /// Reached once there's a real (or degraded in-memory) identity to play
  /// with — either straight from [_begin] (a returning account, or no
  /// account system at all) or via [AccountScreen.onAuthenticated] (a
  /// freshly created/signed-in one). Loads this account's settings once
  /// here (rather than never, or on every turn) so [OnboardingScreen] can be
  /// gated on [UserSettings.hasSeenOnboarding] correctly even for an account
  /// that signed up, then closed the app before ever finishing onboarding —
  /// not just one that finishes it in the same sitting it was created.
  Future<void> _afterAuth() async {
    final settingsPort = widget.controller.settingsPort;
    if (settingsPort == null) {
      _goToWorldSelect();
      return;
    }
    setState(() => _checkingOnboarding = true);
    final settings = await settingsPort.loadSettings();
    if (!mounted) return;
    setState(() => _checkingOnboarding = false);
    widget.controller.updateSettings(settings);
    if (settings.hasSeenOnboarding) {
      _goToWorldSelect();
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        // `onDone` closes over `pageContext`, not this State's own
        // `context`: by the time it fires, `OnboardingScreen` is what's
        // actually mounted and live — `_SplashScreenState` itself was
        // already disposed the moment this very `pushReplacement` replaced
        // its route (the "already signed in, no AccountScreen push in
        // between" path never pushes anything on top of Splash first, so
        // this route IS Splash's own). Reaching back into a disposed
        // State's `context` for the *next* navigation would throw.
        pageBuilder: (pageContext, _, _) => OnboardingScreen(
          controller: widget.controller,
          settingsPort: settingsPort,
          onDone: (module) =>
              _goToWorldSelectFrom(pageContext, widget.controller, autoOpenModule: module),
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _goToWorldSelect({StoryModule? autoOpenModule}) =>
      _goToWorldSelectFrom(context, widget.controller, autoOpenModule: autoOpenModule);

  @override
  Widget build(BuildContext context) {
    // Respect the OS "reduce motion" preference: hold the tome open, still.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _c.isAnimating) _c.stop();

    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          // A fixed-height brand block + pitch/CTA block never fits every
          // viewport this same code runs on (phone/tablet/web, CLAUDE.md §3)
          // — a short window (landscape phone, a resized desktop browser)
          // needs this to scroll instead of overflowing. `Spacer`/`Expanded`
          // can't live inside a `SingleChildScrollView` (unbounded main
          // axis) to distribute the gap between the two blocks, so the gap
          // is sized as an explicit fraction of `viewport.maxHeight`
          // (V2 design prototype §10a: the brand sits near the top, the
          // pitch + "Comenzar" sit near the bottom, not one centered block)
          // — `ConstrainedBox(minHeight)` + `Align(topCenter)` still lets a
          // short viewport scroll instead of clipping.
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.all(AetherSpace.xl),
                      child: _EntranceFade(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: viewport.maxHeight * 0.10),
                            AnimatedBuilder(
                              animation: _c,
                              builder: (context, _) =>
                                  BrandMark(size: 66, filled: false, glow: _c.value),
                            ),
                            const SizedBox(height: AetherSpace.xl),
                            AnimatedBuilder(
                              animation: _c,
                              builder: (context, _) => _Wordmark(shimmer: _c.value),
                            ),
                            const SizedBox(height: AetherSpace.lg),
                            const _OrnamentDivider(),
                            const SizedBox(height: AetherSpace.lg),
                            Text(
                              'Un multiverso que se escribe contigo.',
                              textAlign: TextAlign.center,
                              style: AetherType.body.copyWith(
                                  color: AetherColors.parchmentDim,
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic),
                            ),
                            SizedBox(height: viewport.maxHeight * 0.18),
                            const _ExplainerLines(),
                            const SizedBox(height: AetherSpace.xl),
                            _PrimaryButton(
                              label: 'Comenzar',
                              busy: _checkingOnboarding,
                              onTap: _checkingOnboarding ? null : _begin,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pushes [WorldSelectScreen] as a replacement, using whichever
/// [BuildContext] is actually live at the time — see the comment on its one
/// caller inside [_SplashScreenState._afterAuth]'s `OnboardingScreen`
/// `pageBuilder` for why this can't always be `_SplashScreenState`'s own
/// `context` (that State can already be disposed by the time
/// `OnboardingScreen.onDone` fires).
void _goToWorldSelectFrom(BuildContext context, GameController controller,
    {StoryModule? autoOpenModule}) {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      transitionDuration: AetherMotion.slow,
      pageBuilder: (_, _, _) => WorldSelectScreen(
        controller: controller,
        autoOpenModule: autoOpenModule,
      ),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

// ── Wordmark ──────────────────────────────────────────────────────────────

/// The title treatment: a heavy serif slab with a soft ember glow sitting
/// behind it and a slow gold shimmer sweeping across the letterforms — the
/// single most ceremonial element on screen, so it earns its own painter
/// instead of a plain styled [Text].
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.shimmer});

  /// 0..1 loop position, reused from the tome's animation so the whole
  /// screen breathes on one clock instead of several out-of-sync timers.
  final double shimmer;

  static const _text = 'Aetherbook';
  static const _style = TextStyle(
    fontFamily: 'Marcellus',
    fontSize: 40,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.2,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    // The shimmer highlight travels left-to-right and loops; a wide,
    // soft-edged band rather than a hard line so it reads as a gleam, not a
    // scan.
    final sweep = (shimmer * 2.6) - 0.8;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ember glow, blurred well past the glyph edges.
        Text(
          _text,
          style: _style.copyWith(
            color: AetherColors.gold.withValues(alpha: 0.55),
            shadows: [
              Shadow(
                  color: AetherColors.gold.withValues(alpha: 0.6),
                  blurRadius: 28),
            ],
          ),
        ),
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            colors: const [
              AetherColors.goldSoft,
              AetherColors.goldBright,
              Colors.white,
              AetherColors.goldBright,
              AetherColors.goldSoft,
            ],
            stops: [
              (sweep - 0.35).clamp(0.0, 1.0),
              (sweep - 0.12).clamp(0.0, 1.0),
              sweep.clamp(0.0, 1.0),
              (sweep + 0.12).clamp(0.0, 1.0),
              (sweep + 0.35).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: Text(_text, style: _style),
        ),
      ],
    );
  }
}

/// A small heraldic rule under the wordmark — two hairlines flanking a
/// diamond — the kind of flourish that signals "this is a tome", not a form.
class _OrnamentDivider extends StatelessWidget {
  const _OrnamentDivider();

  @override
  Widget build(BuildContext context) {
    Widget line() => Container(
          width: 42,
          height: 1,
          color: AetherColors.hairlineStrong,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AetherColors.gold,
                boxShadow: AetherShadow.glow(AetherColors.gold, strength: 0.6),
              ),
            ),
          ),
        ),
        line(),
      ],
    );
  }
}

// ── Explainer lines ─────────────────────────────────────────────────────────

/// Three short lines saying what this actually is (V2 prototype §10a) —
/// there was no such explanation on the splash screen before. Grounded in
/// what the app actually does: freeform action instead of A/B choices,
/// long-memory continuity, and the 5-worlds-or-your-own breadth (CLAUDE.md §1).
class _ExplainerLines extends StatelessWidget {
  const _ExplainerLines();

  static const _lines = [
    (Icons.edit_note_rounded, 'Escribes lo que quieras hacer; no eliges entre A y B'),
    (Icons.psychology_outlined, 'El mundo recuerda lo que hiciste hace veinte turnos'),
    (Icons.public_rounded, 'Cinco mundos, o el que escribas tú'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, text) in _lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AetherSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 19, color: AetherColors.goldBright),
                const SizedBox(width: AetherSpace.md),
                Expanded(
                  child: Text(
                    text,
                    style: AetherType.body.copyWith(fontSize: 13.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Primary button ──────────────────────────────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AetherMotion.fast,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AetherSpace.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AetherColors.surfaceRaised, AetherColors.ink],
            ),
            border: Border.all(color: AetherColors.gold.withValues(alpha: 0.55)),
            borderRadius: AetherRadius.allMd,
            boxShadow: AetherShadow.glow(AetherColors.gold,
                strength: _pressed ? 0.45 : 0.3),
          ),
          child: widget.busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AetherColors.goldBright),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AetherColors.goldBright,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: AetherSpace.sm),
                    const Icon(Icons.arrow_forward_rounded,
                        color: AetherColors.goldBright, size: 19),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Entrance fade ───────────────────────────────────────────────────────────

class _EntranceFade extends StatelessWidget {
  const _EntranceFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: AetherMotion.standard,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: child,
    );
  }
}

