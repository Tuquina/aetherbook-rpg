/// Thrown by [AuthPort.signUpWithPassword] when the email already belongs
/// to a different account (V2 design prototype §10d: "si ese correo ya
/// tenía cuenta"). The player should be offered [AuthPort.signInWithPassword]
/// instead — never retried automatically, since the current session has no
/// way to know what that account's password is.
class EmailAlreadyRegisteredException implements Exception {
  const EmailAlreadyRegisteredException(this.email);

  final String email;

  @override
  String toString() =>
      'EmailAlreadyRegisteredException: $email already has an account';
}

/// Player identity (CLAUDE.md §4: kept behind a port so the UI never
/// imports a concrete auth provider directly). A real account (Google or
/// email+password) is required before any session exists at all —
/// `SplashScreen` gates "Comenzar" on [isAnonymous] and routes to
/// `AccountScreen` first when there isn't one yet. There is deliberately no
/// anonymous or guest path: the player must sign up or sign in before
/// playing.
///
/// V2 (`V2_PRODUCT_DECISIONS.md` Decision D, later revised): replaces the
/// original email-magic-link-only model with Google OAuth + email/password
/// — magic-link is discontinued entirely, not kept alongside these — and
/// removes the anonymous-first bootstrap that Decision D itself still
/// assumed, per the user's explicit later instruction that guest play should
/// no longer be possible at all.
abstract class AuthPort {
  /// Whether there's no signed-in identity yet — `true` before the player
  /// has signed up or signed in at all.
  bool get isAnonymous;

  /// The email attached to the current session, or `null` while anonymous.
  String? get email;

  /// When the current account was created, or `null` while anonymous —
  /// powers Perfil's "Lector desde" (a month name, V2 design prototype §6a).
  DateTime? get accountCreatedAt;

  /// Fires whenever the signed-in identity changes (signed in, switched
  /// accounts, signed out) — lets UI reflect the current state reactively
  /// instead of polling. Load-bearing for [signInWithGoogle] specifically:
  /// the OAuth round trip completes asynchronously (the player leaves the
  /// app for a consent screen and comes back later), so a UI can't just
  /// wait on that method's `Future` to know when it actually finished.
  Stream<void> get onChange;

  /// Signs up or signs into a Google account (V2 design prototype §10b) —
  /// creates a real account directly; there's no anonymous session to
  /// attach to. Completion is reported via [onChange], not this method's
  /// `Future` (see its doc comment).
  Future<void> signInWithGoogle();

  /// Creates a new email+password account. Throws
  /// [EmailAlreadyRegisteredException] if [email] already belongs to a
  /// different account.
  Future<void> signUpWithPassword({required String email, required String password});

  /// Signs into an *existing* email+password account.
  Future<void> signInWithPassword({required String email, required String password});

  /// Sends a password-reset email. Resolves the same way regardless of
  /// whether [email] has an account, to avoid revealing which emails are
  /// registered (V2 design prototype §10d: "no confirmar si el correo existe
  /// evita que alguien averigüe quién tiene cuenta").
  Future<void> resetPassword(String email);

  /// Ends the current session (V2 design prototype §6b: "Cerrar sesión").
  /// [isAnonymous] becomes `true` again afterwards — the same state as
  /// before ever signing in.
  Future<void> signOut();
}
