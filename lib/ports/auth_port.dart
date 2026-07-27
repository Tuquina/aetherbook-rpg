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
/// imports a concrete auth provider directly). The app always has *some*
/// signed-in session from launch — anonymous, transparently, so play never
/// requires an account up front. This port exists only for the player
/// choosing to attach a durable identity to that session, to carry their
/// progress across devices/browsers instead of it staying tied to one
/// browser's local storage.
///
/// V2 (`V2_PRODUCT_DECISIONS.md` Decision D): replaces the original
/// email-magic-link-only model with Google OAuth + email/password, per the
/// user's explicit choice — magic-link is discontinued entirely, not kept
/// alongside these.
abstract class AuthPort {
  /// Whether the current session has no durable identity attached yet.
  bool get isAnonymous;

  /// The email attached to the current session, or `null` while anonymous.
  String? get email;

  /// Fires whenever the signed-in identity changes (linked, switched
  /// accounts, signed out) — lets UI reflect the current state reactively
  /// instead of polling. Load-bearing for [signInWithGoogle] specifically:
  /// the OAuth round trip completes asynchronously (the player leaves the
  /// app for a consent screen and comes back later), so a UI can't just
  /// wait on that method's `Future` to know when linking actually finished.
  Stream<void> get onChange;

  /// Links a Google identity to the current session (V2 design prototype
  /// §10b) — preserves whatever the session already had, unlike
  /// [signInWithPassword]. Completion is reported via [onChange], not this
  /// method's `Future` (see its doc comment).
  Future<void> signInWithGoogle();

  /// Creates a new email+password account, linked to the current (until-now
  /// anonymous) session — same "keep today's progress" model the old
  /// magic-link flow had, now with a password instead of an emailed link.
  /// Throws [EmailAlreadyRegisteredException] if [email] already belongs to
  /// a different account.
  Future<void> signUpWithPassword({required String email, required String password});

  /// Signs into an *existing* email+password account. Unlike
  /// [signUpWithPassword]/[signInWithGoogle], this switches the session away
  /// from whatever it currently had — any local, unlinked progress is left
  /// behind (V2 design prototype §10d's explicit warning).
  Future<void> signInWithPassword({required String email, required String password});

  /// Sends a password-reset email. Resolves the same way regardless of
  /// whether [email] has an account, to avoid revealing which emails are
  /// registered (V2 design prototype §10d: "no confirmar si el correo existe
  /// evita que alguien averigüe quién tiene cuenta").
  Future<void> resetPassword(String email);
}
