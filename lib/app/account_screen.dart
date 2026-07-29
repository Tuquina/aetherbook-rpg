import 'dart:async';

import 'package:flutter/material.dart';

import '../ports/auth_port.dart';
import 'design/breakpoints.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'widgets/atmosphere.dart';
import 'widgets/brand_lockup.dart';
import 'widgets/brand_mark.dart';
import 'widgets/google_logo.dart';
import 'widgets/scrollable_centered.dart';

/// Where the player creates or signs into the real account required to play
/// at all (V2: no anonymous/guest path — `SplashScreen` reaches this screen
/// whenever [AuthPort.isAnonymous] is still true, and [onAuthenticated] is
/// how this screen hands control back once that stops being the case). The
/// heavy lifting (which Supabase call to make) lives entirely behind
/// [AuthPort]; this widget only renders whichever state it's in.
///
/// V2 (`V2_PRODUCT_DECISIONS.md` Decision D, later revised): replaces the
/// single email-magic-link form with Google + email/password, discontinuing
/// the magic link entirely, and — per the user's later explicit instruction
/// — this screen is no longer skippable: there's no "seguir sin cuenta".
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.authPort, required this.onAuthenticated});

  final AuthPort authPort;

  /// Called once [authPort] reports a real (non-anonymous) identity — right
  /// after a synchronous sign-in success, or later via [AuthPort.onChange]
  /// for Google's asynchronous consent-screen round trip. The caller owns
  /// what happens next (`SplashScreen` replaces this screen with
  /// `WorldSelectScreen`); this widget never navigates on its own beyond
  /// that.
  final VoidCallback onAuthenticated;

  static Route<void> route({
    required AuthPort authPort,
    required VoidCallback onAuthenticated,
  }) =>
      MaterialPageRoute(
        builder: (_) => AccountScreen(authPort: authPort, onAuthenticated: onAuthenticated),
      );

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _Mode { signUp, signIn, forgotPassword }

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Mode _mode = _Mode.signUp;
  bool _submitting = false;
  String? _error;
  bool _signUpSent = false;
  bool _resetSent = false;

  /// Set when [_signUpWithPassword] hits `EmailAlreadyRegisteredException`
  /// (V2 design prototype §10d) — offers switching to sign-in instead of
  /// retrying blind.
  bool _emailTakenWarning = false;

  late final StreamSubscription<void> _authSub;

  @override
  void initState() {
    super.initState();
    // Google's signInWithOAuth() only launches the consent screen; actual
    // completion arrives later via onChange once the player comes back from
    // it (AuthPort.signInWithGoogle's doc comment) — this is the only way
    // this screen finds out.
    _authSub = widget.authPort.onChange.listen((_) {
      if (mounted && !widget.authPort.isAnonymous) widget.onAuthenticated();
    });
    // Defensive: if this screen somehow opened while already authenticated
    // (shouldn't happen given SplashScreen's own gating, but nothing here
    // should assume its caller got that right), hand control back
    // immediately instead of showing a sign-up form for no reason. Deferred
    // a frame since navigating during initState/build is unsafe.
    if (!widget.authPort.isAnonymous) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAuthenticated();
      });
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _emailLooksValid {
    final value = _emailController.text.trim();
    final at = value.indexOf('@');
    return at > 0 && at < value.length - 1 && !value.substring(at + 1).contains('@');
  }

  bool get _passwordLooksValid => _passwordController.text.length >= 8;

  void _switchMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _emailTakenWarning = false;
      _signUpSent = false;
      _resetSent = false;
      _passwordController.clear();
    });
  }

  Future<void> _signInWithGoogle() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.authPort.signInWithGoogle();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos conectar con Google. Prueba de nuevo.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signUp() async {
    if (!_emailLooksValid || !_passwordLooksValid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _emailTakenWarning = false;
    });
    try {
      await widget.authPort.signUpWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _signUpSent = true;
      });
    } on EmailAlreadyRegisteredException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _emailTakenWarning = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'No pudimos crear la cuenta. Prueba de nuevo en un momento.';
      });
    }
  }

  Future<void> _signIn() async {
    if (!_emailLooksValid || _passwordController.text.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.authPort.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Not calling widget.onAuthenticated() here directly: signing in also
      // fires AuthPort.onChange (same as Google's), which the listener in
      // initState already handles — calling it from both places would fire
      // it twice.
      if (!mounted) return;
      setState(() => _submitting = false);
    } catch (_) {
      // Never reveal whether the email or the password was wrong.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'No pudimos iniciar sesión. Revisa tu email y tu contraseña.';
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_emailLooksValid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.authPort.resetPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _resetSent = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'No pudimos enviar el correo. Prueba de nuevo en un momento.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final desktop = viewport.maxWidth >= AetherBreakpoints.desktop;
              return desktop ? _buildDesktop(context) : _buildMobile(context);
            },
          ),
        ),
      ),
    );
  }

  /// Phone and tablet — unchanged from before the desktop split layout
  /// existed. A scrollable `ListView`, not a fixed centered `Column`: the
  /// form can overflow a short viewport — a small phone in landscape, or
  /// the keyboard eating half the screen — same reason `ChargenScreen`
  /// scrolls instead of centering its content.
  Widget _buildMobile(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(
          padding: const EdgeInsets.all(AetherSpace.xl),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AetherColors.goldSoft),
              ),
            ),
            const SizedBox(height: AetherSpace.lg),
            const BrandMark(size: 44),
            const SizedBox(height: AetherSpace.lg),
            ..._modeContent(),
          ],
        ),
      ),
    );
  }

  /// Desktop — the same 440px-wide form used to float alone in the middle
  /// of the whole browser window, no different from a phone screen just
  /// stretched into empty space. A two-panel split instead, matching
  /// `SplashScreen`'s own desktop layout so "arrival" and "sign in" read as
  /// one coherent flow rather than two unrelated screens: a [BrandLockup]
  /// on the wide side (smaller than the splash's own, and with no tagline —
  /// a player only reaches this screen after already seeing that pitch
  /// once), the actual form in a bordered card on a fixed-width side.
  Widget _buildDesktop(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AetherSpace.huge),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: const BrandLockup(markSize: 88, wordmarkFontSize: 50),
              ),
            ),
          ),
          const SizedBox(width: AetherSpace.huge),
          SizedBox(
            width: 460,
            child: ScrollableCentered(
              child: Container(
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AetherColors.goldSoft),
                      ),
                    ),
                    const SizedBox(height: AetherSpace.sm),
                    ..._modeContent(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The mode-dependent body (sign up / sign in / forgot password / sent
  /// confirmations) — identical on mobile and desktop, only the chrome
  /// around it (a loose `ListView` vs. a bordered card) differs.
  List<Widget> _modeContent() {
    if (_mode == _Mode.forgotPassword) return _forgotPasswordContent();
    if (_signUpSent) return _signUpSentContent();
    return [
      ..._googleContent(),
      const SizedBox(height: AetherSpace.xl),
      _OrDivider(),
      const SizedBox(height: AetherSpace.xl),
      if (_emailTakenWarning) ...[
        _EmailTakenWarning(
          onSwitchToSignIn: () => _switchMode(_Mode.signIn),
        ),
        const SizedBox(height: AetherSpace.lg),
      ],
      if (_mode == _Mode.signUp) ..._signUpContent() else ..._signInContent(),
    ];
  }

  List<Widget> _googleContent() => [
        _GoogleButton(
          enabled: !_submitting,
          busy: _submitting,
          onTap: _signInWithGoogle,
        ),
      ];

  List<Widget> _signUpContent() => [
        Text('Crea tu cuenta', style: AetherType.display.copyWith(fontSize: 22)),
        const SizedBox(height: AetherSpace.md),
        Text(
          'Tu historia se guarda en la nube, ligada a tu cuenta — hace falta '
          'una para jugar. Con Google es un toque; con correo y contraseña, '
          'unos segundos más.',
          style: AetherType.body,
        ),
        const SizedBox(height: AetherSpace.xl),
        _EmailField(
          controller: _emailController,
          enabled: !_submitting,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: AetherSpace.sm),
        _PasswordField(
          controller: _passwordController,
          enabled: !_submitting,
          onChanged: () => setState(() {}),
          onSubmit: _signUp,
        ),
        const SizedBox(height: 6),
        Text('Ocho caracteres o más.', style: AetherType.caption),
        if (_error != null) ...[
          const SizedBox(height: AetherSpace.md),
          Text(_error!, style: AetherType.body.copyWith(color: AetherColors.failure)),
        ],
        const SizedBox(height: AetherSpace.xl),
        _SubmitButton(
          label: 'Crear cuenta',
          enabled: _emailLooksValid && _passwordLooksValid && !_submitting,
          busy: _submitting,
          onTap: _signUp,
        ),
        const SizedBox(height: AetherSpace.lg),
        Center(
          child: _TextLink(
            label: '¿Ya tienes cuenta? Entrar',
            onTap: () => _switchMode(_Mode.signIn),
          ),
        ),
      ];

  List<Widget> _signInContent() => [
        Text('Entra a tu cuenta', style: AetherType.display.copyWith(fontSize: 22)),
        const SizedBox(height: AetherSpace.md),
        Text(
          'Entra con tu cuenta para seguir tu historia donde la dejaste.',
          style: AetherType.body,
        ),
        const SizedBox(height: AetherSpace.xl),
        _EmailField(
          controller: _emailController,
          enabled: !_submitting,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: AetherSpace.sm),
        _PasswordField(
          controller: _passwordController,
          enabled: !_submitting,
          onChanged: () => setState(() {}),
          onSubmit: _signIn,
        ),
        if (_error != null) ...[
          const SizedBox(height: AetherSpace.md),
          Text(_error!, style: AetherType.body.copyWith(color: AetherColors.failure)),
        ],
        const SizedBox(height: AetherSpace.xl),
        _SubmitButton(
          label: 'Entrar',
          enabled: _emailLooksValid && _passwordController.text.isNotEmpty && !_submitting,
          busy: _submitting,
          onTap: _signIn,
        ),
        const SizedBox(height: AetherSpace.lg),
        Center(
          child: _TextLink(
            label: 'Olvidé mi contraseña',
            onTap: () => _switchMode(_Mode.forgotPassword),
          ),
        ),
        const SizedBox(height: AetherSpace.sm),
        Center(
          child: _TextLink(
            label: '¿No tienes cuenta? Crear una',
            onTap: () => _switchMode(_Mode.signUp),
          ),
        ),
      ];

  List<Widget> _forgotPasswordContent() {
    if (_resetSent) {
      return [
        const Icon(Icons.mark_email_read_rounded, color: AetherColors.goldBright, size: 32),
        const SizedBox(height: AetherSpace.lg),
        Text('Revisa tu correo', style: AetherType.display.copyWith(fontSize: 22)),
        const SizedBox(height: AetherSpace.md),
        Text(
          'Si hay una cuenta con ese correo, te llega un enlace para cambiar '
          'la contraseña.',
          style: AetherType.body,
        ),
      ];
    }
    return [
      Text('Olvidé mi contraseña', style: AetherType.display.copyWith(fontSize: 22)),
      const SizedBox(height: AetherSpace.md),
      Text(
        'Un correo, un botón, y la misma respuesta siempre — exista o no una '
        'cuenta con ese email.',
        style: AetherType.body,
      ),
      const SizedBox(height: AetherSpace.xl),
      _EmailField(
        controller: _emailController,
        enabled: !_submitting,
        onChanged: () => setState(() {}),
      ),
      if (_error != null) ...[
        const SizedBox(height: AetherSpace.md),
        Text(_error!, style: AetherType.body.copyWith(color: AetherColors.failure)),
      ],
      const SizedBox(height: AetherSpace.xl),
      _SubmitButton(
        label: 'Enviar enlace',
        enabled: _emailLooksValid && !_submitting,
        busy: _submitting,
        onTap: _resetPassword,
      ),
      const SizedBox(height: AetherSpace.lg),
      Center(
        child: _TextLink(
          label: 'Volver a entrar',
          onTap: () => _switchMode(_Mode.signIn),
        ),
      ),
    ];
  }

  List<Widget> _signUpSentContent() => [
        const Icon(Icons.mark_email_read_rounded, color: AetherColors.goldBright, size: 32),
        const SizedBox(height: AetherSpace.lg),
        Text('Revisa tu correo', style: AetherType.display.copyWith(fontSize: 22)),
        const SizedBox(height: AetherSpace.md),
        Text(
          'Te mandamos un enlace a ${_emailController.text.trim()}. Al '
          'confirmarlo, ya puedes entrar y empezar a jugar con esta cuenta '
          'desde cualquier dispositivo.',
          style: AetherType.body,
        ),
      ];
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AetherColors.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md),
          child: Text('o', style: AetherType.overline),
        ),
        const Expanded(child: Divider(color: AetherColors.hairline)),
      ],
    );
  }
}

class _EmailTakenWarning extends StatelessWidget {
  const _EmailTakenWarning({required this.onSwitchToSignIn});

  final VoidCallback onSwitchToSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AetherSpace.md),
      decoration: BoxDecoration(
        color: AetherColors.surfaceRaised,
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: AetherColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AetherColors.goldSoft, size: 18),
              const SizedBox(width: AetherSpace.sm),
              Expanded(
                child: Text('Ese correo ya tiene cuenta',
                    style: AetherType.label.copyWith(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: AetherSpace.sm),
          Text(
            'No creamos otra — probablemente sea la que abriste en otro '
            'dispositivo. Entra con esa cuenta en cambio.',
            style: AetherType.caption,
          ),
          const SizedBox(height: AetherSpace.md),
          _TextLink(label: 'Entrar con ese email', onTap: onSwitchToSignIn),
        ],
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AetherType.label.copyWith(color: AetherColors.goldSoft, fontSize: 13),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, required this.enabled, required this.onChanged});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      onChanged: (_) => onChanged(),
      style: AetherType.body.copyWith(fontSize: 15),
      cursorColor: AetherColors.gold,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AetherSpace.lg, vertical: AetherSpace.md),
        hintText: 'tu@email.com',
        hintStyle:
            AetherType.caption.copyWith(color: AetherColors.parchmentFaint, fontSize: 15),
        prefixIcon: const Icon(Icons.mail_outline_rounded,
            size: 18, color: AetherColors.parchmentFaint),
        filled: true,
        fillColor: AetherColors.void_,
        enabledBorder: const OutlineInputBorder(
          borderRadius: AetherRadius.allMd,
          borderSide: BorderSide(color: AetherColors.hairline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AetherRadius.allMd,
          borderSide: BorderSide(color: AetherColors.gold),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      textInputAction: TextInputAction.send,
      onChanged: (_) => widget.onChanged(),
      onSubmitted: (_) => widget.onSubmit(),
      style: AetherType.body.copyWith(fontSize: 15),
      cursorColor: AetherColors.gold,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AetherSpace.lg, vertical: AetherSpace.md),
        hintText: 'Contraseña',
        hintStyle:
            AetherType.caption.copyWith(color: AetherColors.parchmentFaint, fontSize: 15),
        prefixIcon:
            const Icon(Icons.key_rounded, size: 18, color: AetherColors.parchmentFaint),
        filled: true,
        fillColor: AetherColors.void_,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 18,
            color: AetherColors.parchmentFaint,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AetherRadius.allMd,
          borderSide: BorderSide(color: AetherColors.hairline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AetherRadius.allMd,
          borderSide: BorderSide(color: AetherColors.gold),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.enabled, required this.busy, required this.onTap});

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AetherSpace.lg),
        decoration: BoxDecoration(
          color: AetherColors.parchment,
          borderRadius: AetherRadius.allMd,
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AetherColors.ink),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GoogleLogo(size: 20),
                    const SizedBox(width: AetherSpace.sm),
                    Text(
                      'Continuar con Google',
                      style: TextStyle(
                        color: AetherColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AetherSpace.lg),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(colors: [AetherColors.gold, AetherColors.goldBright])
              : null,
          color: enabled ? null : AetherColors.surfaceRaised,
          borderRadius: AetherRadius.allMd,
          boxShadow: enabled ? AetherShadow.glow(AetherColors.gold, strength: 0.35) : null,
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AetherColors.void_),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: enabled ? AetherColors.void_ : AetherColors.parchmentFaint,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
