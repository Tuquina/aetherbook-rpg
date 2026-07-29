import 'package:flutter/material.dart';

import '../ports/auth_port.dart';
import 'account_screen.dart';
import 'design/breakpoints.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'onboarding_screen.dart';
import 'widgets/atmosphere.dart';
import 'widgets/brand_lockup.dart';
import 'widgets/scrollable_centered.dart';
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

class _SplashScreenState extends State<SplashScreen> {
  bool _checkingOnboarding = false;

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
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final desktop = viewport.maxWidth >= AetherBreakpoints.desktop;
              return _EntranceFade(
                child: desktop ? _buildDesktop() : _buildCompact(viewport),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Phone and tablet (`< AetherBreakpoints.desktop`) — a single centered
  /// column, unchanged from before the desktop split layout existed.
  ///
  /// A fixed-height brand block + pitch/CTA block never fits every viewport
  /// this same code runs on (phone/tablet, CLAUDE.md §3) — a short window
  /// (landscape phone) needs this to scroll instead of overflowing. The gap
  /// between the two blocks is *not* a `Spacer`/`Expanded` (those can't live
  /// inside a `SingleChildScrollView`'s unbounded main axis — the exact bug
  /// this replaced: on any phone tall enough that both blocks' actual
  /// content was shorter than the two hand-picked `viewport.maxHeight`
  /// fractions, `Align(topCenter)` still left the CTA block floating
  /// mid-screen with dead space below it, instead of pinned to the bottom
  /// edge as V2 §10a shows it). `Column(mainAxisAlignment: spaceBetween)`
  /// needs no Flexible child to do this: fed `BoxConstraints(minHeight:
  /// viewport, maxHeight: infinity)` by the `ConstrainedBox`, a `Column`
  /// with no flex children sizes itself to `max(childrenHeight, minHeight)`
  /// and only then distributes *actual* leftover space between its children
  /// — which is exactly "brand block at the top, CTA block at the bottom,
  /// gap absorbs whatever's left" on any viewport, and still just grows
  /// (and scrolls) past `minHeight` if the content itself is taller. This is
  /// why the 440-wide reading measure lives on each *block* individually
  /// (`ConstrainedBox(maxWidth: 440)`, centered by the outer `Column`'s own
  /// default `crossAxisAlignment.center`) instead of wrapping the whole
  /// thing in an outer `Center`/`Align` — either of those shrink-wraps to
  /// its child's natural height under an unbounded incoming `maxHeight`,
  /// silently undoing the stretch this fix depends on.
  Widget _buildCompact(BoxConstraints viewport) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewport.maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(AetherSpace.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Centered within the top *half* of the viewport (not flush
              // against the top edge), so its own center sits at roughly
              // 1/4 of the screen height — an explicit height, not
              // `Expanded`, for the same "no flex inside a scrollable's
              // unbounded main axis" reason the rest of this layout avoids
              // it. The bottom (CTA) block's own flush-to-bottom behavior
              // is untouched: with only two children left in this
              // `spaceBetween` Column, the single gap between them still
              // absorbs 100% of the leftover space, so the CTA block's
              // bottom edge still lands exactly on the viewport's bottom
              // edge either way.
              SizedBox(
                height: viewport.maxHeight * 0.5,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: const BrandLockup(
                      tagline: 'Un multiverso que se escribe contigo.',
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _ExplainerLines(),
                    const SizedBox(height: AetherSpace.xl),
                    _PrimaryButton(
                      label: 'Comenzar',
                      busy: _checkingOnboarding,
                      onTap: _checkingOnboarding ? null : _begin,
                    ),
                    if (widget.auth != null) ...[
                      const SizedBox(height: AetherSpace.md),
                      const _SaveProgressCaption(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Desktop (`>= AetherBreakpoints.desktop`) — the mobile-shaped single
  /// column used to just float, centered, in a sea of empty space on a wide
  /// browser window (nothing here ever adapted past a 440px reading
  /// measure). A two-panel split instead: a hero-scale [BrandLockup] fills
  /// the wide side, and the actual entry action lives in a bordered card on
  /// a fixed-width side — the same "surface + hairlineStrong border" card
  /// language every other card in the app already uses (`StoryCard`, the
  /// module cards), not a new one-off treatment.
  Widget _buildDesktop() {
    return Padding(
      padding: const EdgeInsets.all(AetherSpace.huge),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: const BrandLockup(
                  markSize: 108,
                  wordmarkFontSize: 62,
                  tagline: 'Un multiverso que se escribe contigo.',
                ),
              ),
            ),
          ),
          const SizedBox(width: AetherSpace.huge),
          SizedBox(
            width: 440,
            child: ScrollableCentered(
              child: _DesktopEntranceCard(
                checkingOnboarding: _checkingOnboarding,
                onBegin: _begin,
                showSaveCaption: widget.auth != null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The desktop split layout's right-hand panel: same explainer lines,
/// "Comenzar" button and save-progress caption as the compact layout's
/// bottom block, just inside a bordered card instead of loose on the page.
class _DesktopEntranceCard extends StatelessWidget {
  const _DesktopEntranceCard({
    required this.checkingOnboarding,
    required this.onBegin,
    required this.showSaveCaption,
  });

  final bool checkingOnboarding;
  final VoidCallback onBegin;
  final bool showSaveCaption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.xxl),
      decoration: BoxDecoration(
        color: AetherColors.surface,
        borderRadius: AetherRadius.allLg,
        border: Border.all(color: AetherColors.hairlineStrong),
        boxShadow: AetherShadow.panel,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ExplainerLines(),
          const SizedBox(height: AetherSpace.xl),
          _PrimaryButton(
            label: 'Comenzar',
            busy: checkingOnboarding,
            onTap: checkingOnboarding ? null : onBegin,
          ),
          if (showSaveCaption) ...[
            const SizedBox(height: AetherSpace.md),
            const _SaveProgressCaption(),
          ],
        ],
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

// ── Save-progress caption ───────────────────────────────────────────────────

/// The small reassurance under "Comenzar" (V2 §10a: "Guardar tu progreso con
/// tu correo") — only shown when there's a real account system to back it
/// ([SplashScreen.auth] non-null; the degraded in-memory-only mode has
/// nothing to save to, so claiming this would be actively wrong there).
class _SaveProgressCaption extends StatelessWidget {
  const _SaveProgressCaption();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_outlined, size: 14, color: AetherColors.parchmentFaint),
        const SizedBox(width: 6),
        Text(
          'Guardar tu progreso con tu correo',
          style: AetherType.caption.copyWith(color: AetherColors.parchmentFaint, fontSize: 12),
        ),
      ],
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

