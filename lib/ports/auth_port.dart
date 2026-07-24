/// What happened after [AuthPort.continueWithEmail] — the two outcomes the
/// UI needs to tailor its confirmation message. Kept provider-agnostic
/// (CLAUDE.md §4/§6: nothing about a specific auth provider leaks past this
/// port) even though today's only adapter is Supabase Auth.
enum EmailLinkOutcome {
  /// [email] was attached to the current (until-now anonymous) session — a
  /// confirmation email was sent. The account only becomes permanent, under
  /// the same user id and with all of today's progress, once the player
  /// clicks it.
  linkConfirmationSent,

  /// [email] already belongs to a different, existing account (e.g. the
  /// player claimed it earlier from another device) — a sign-in link was
  /// sent for *that* account instead. Clicking it switches this device's
  /// session over to it; whatever the current anonymous session had is left
  /// behind.
  signInLinkSent,
}

/// Player identity (CLAUDE.md §4: kept behind a port so the UI never
/// imports a concrete auth provider directly). The app always has *some*
/// signed-in session from launch — anonymous, transparently, so play never
/// requires an account up front. This port exists only for the player
/// choosing to attach a durable email to that session, to carry their
/// progress across devices/browsers instead of it staying tied to one
/// browser's local storage.
abstract class AuthPort {
  /// Whether the current session has no email attached yet.
  bool get isAnonymous;

  /// The email attached to the current session, or `null` while anonymous.
  String? get email;

  /// Fires whenever the signed-in identity changes (linked, switched
  /// accounts, signed out) — lets UI reflect the current state reactively
  /// instead of polling.
  Stream<void> get onChange;

  /// Links [email] to the current session, or — if it already belongs to a
  /// different account — sends that account a sign-in link instead. Either
  /// way, nothing changes locally until the player opens the emailed link.
  Future<EmailLinkOutcome> continueWithEmail(String email);
}
