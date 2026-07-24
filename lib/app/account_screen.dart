import 'package:flutter/material.dart';

import '../ports/auth_port.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'widgets/atmosphere.dart';

/// Lets the player attach a durable email to their (until now anonymous)
/// session. Reached from [SplashScreen]'s account button — purely opt-in,
/// the game plays exactly the same if this screen is never opened. The
/// heavy lifting (which Supabase call to make, and which of the two
/// outcomes it resolves to) lives entirely behind [AuthPort]; this widget
/// only renders whichever of four states it's in.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.authPort});

  final AuthPort authPort;

  static Route<void> route({required AuthPort authPort}) => MaterialPageRoute(
        builder: (_) => AccountScreen(authPort: authPort),
      );

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _Status { idle, sending, sent, error }

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  _Status _status = _Status.idle;
  EmailLinkOutcome? _outcome;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Deliberately permissive (CLAUDE.md domain purity doesn't apply to a
  // client-side hint like this one) — real validation is Supabase's job
  // when the request actually goes out; this only blocks the obviously
  // empty/malformed case so the button isn't a dead end.
  bool get _emailLooksValid {
    final value = _emailController.text.trim();
    final at = value.indexOf('@');
    return at > 0 && at < value.length - 1 && !value.substring(at + 1).contains('@');
  }

  Future<void> _submit() async {
    if (!_emailLooksValid || _status == _Status.sending) return;
    setState(() {
      _status = _Status.sending;
      _error = null;
    });
    try {
      final outcome = await widget.authPort.continueWithEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _status = _Status.sent;
        _outcome = outcome;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _error = 'No pudimos enviar el correo. Probá de nuevo en un momento.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final alreadyLinked = !widget.authPort.isAnonymous;
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              // A scrollable ListView, not a fixed centered Column: the form
              // (title + body copy + field + button) can overflow a short
              // viewport — a small phone in landscape, or the keyboard
              // eating half the screen — the same reason ChargenScreen
              // scrolls instead of centering its content.
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
                  const Icon(Icons.shield_moon_rounded,
                      color: AetherColors.gold, size: 40),
                  const SizedBox(height: AetherSpace.lg),
                  if (alreadyLinked)
                    ..._linkedContent(widget.authPort.email!)
                  else if (_status == _Status.sent)
                    ..._sentContent(_outcome!, _emailController.text.trim())
                  else
                    ..._formContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _linkedContent(String email) => [
        Text('Ya estás guardando tu progreso', style: AetherType.display.copyWith(fontSize: 22)),
        const SizedBox(height: AetherSpace.md),
        Text(
          'Estás jugando con $email. Entrá con este mismo email desde cualquier '
          'otro dispositivo o navegador para seguir donde lo dejaste.',
          style: AetherType.body,
        ),
      ];

  List<Widget> _sentContent(EmailLinkOutcome outcome, String email) => [
        const Icon(Icons.mark_email_read_rounded, color: AetherColors.goldBright, size: 32),
        const SizedBox(height: AetherSpace.lg),
        Text('Revisá tu correo', style: AetherType.display.copyWith(fontSize: 22)),
        const SizedBox(height: AetherSpace.md),
        Text(
          outcome == EmailLinkOutcome.linkConfirmationSent
              ? 'Te mandamos un enlace a $email. Al confirmarlo, tu progreso de '
                  'ahora en más queda guardado en esa cuenta — vas a poder entrar '
                  'con este mismo email desde cualquier otro dispositivo.'
              : 'Ese email ya tiene una cuenta acá. Te mandamos un enlace para '
                  'entrar — abrilo desde este dispositivo para continuar donde '
                  'la dejaste.',
          style: AetherType.body,
        ),
      ];

  List<Widget> _formContent() => [
        Text('Guardá tu progreso', style: AetherType.display.copyWith(fontSize: 22)),
        const SizedBox(height: AetherSpace.md),
        Text(
          'Hoy tu partida vive solo en este dispositivo. Dejanos tu email y te '
          'mandamos un enlace: al confirmarlo, tu progreso queda ligado a esa '
          'cuenta y podés seguir jugando desde cualquier otro dispositivo sin '
          'perder nada.',
          style: AetherType.body,
        ),
        const SizedBox(height: AetherSpace.xl),
        _EmailField(
          controller: _emailController,
          enabled: _status != _Status.sending,
          onChanged: () => setState(() {}),
          onSubmit: _submit,
        ),
        if (_error != null) ...[
          const SizedBox(height: AetherSpace.md),
          Text(_error!, style: AetherType.body.copyWith(color: AetherColors.failure)),
        ],
        const SizedBox(height: AetherSpace.xl),
        _SubmitButton(
          enabled: _emailLooksValid && _status != _Status.sending,
          busy: _status == _Status.sending,
          onTap: _submit,
        ),
      ];
}

class _EmailField extends StatelessWidget {
  const _EmailField({
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
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.send,
      autocorrect: false,
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmit(),
      style: AetherType.body.copyWith(fontSize: 15),
      cursorColor: AetherColors.gold,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AetherSpace.lg, vertical: AetherSpace.md),
        hintText: 'tu@email.com',
        hintStyle:
            AetherType.caption.copyWith(color: AetherColors.parchmentFaint, fontSize: 15),
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

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.enabled, required this.busy, required this.onTap});

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
                  'Enviar enlace',
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
