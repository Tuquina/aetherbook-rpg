import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ports/auth_port.dart';

/// Wraps Supabase Auth (CLAUDE.md §4/§8: the only file that talks to
/// `supabase_flutter`'s `auth` surface directly). Owns the whole identity
/// lifecycle: the transparent anonymous bootstrap at launch
/// ([ensureSignedIn]) and the player-initiated upgrade to a durable email
/// ([continueWithEmail]).
class SupabaseAuthAdapter implements AuthPort {
  SupabaseAuthAdapter(this._client, {this.emailRedirectTo});

  final SupabaseClient _client;

  /// Where Supabase redirects the player after they click the emailed link
  /// — must be allow-listed in the project's Auth > URL Configuration.
  /// `null` falls back to the project's configured Site URL.
  final String? emailRedirectTo;

  GoTrueClient get _auth => _client.auth;

  @override
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Stream<void> get onChange => _auth.onAuthStateChange;

  /// Signs in anonymously if nothing is signed in yet — a no-op once *any*
  /// session (anonymous or permanent) already exists, so it's safe to call
  /// on every app launch. This replaces the inline `signInAnonymously` call
  /// `main.dart` used to make directly against `Supabase.instance.client`.
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  @override
  Future<EmailLinkOutcome> continueWithEmail(String email) async {
    try {
      await _auth.updateUser(
        UserAttributes(email: email),
        emailRedirectTo: emailRedirectTo,
      );
      return EmailLinkOutcome.linkConfirmationSent;
    } on AuthApiException catch (e) {
      if (!isEmailAlreadyTakenError(e)) rethrow;
      // Already someone else's account — most likely this same player,
      // claimed from a previous device. Sign *that* account in instead of
      // creating a new one (shouldCreateUser: false) — the current
      // anonymous session's local state is left behind, same as any
      // sign-in into a pre-existing account would.
      await _auth.signInWithOtp(
        email: email,
        emailRedirectTo: emailRedirectTo,
        shouldCreateUser: false,
      );
      return EmailLinkOutcome.signInLinkSent;
    }
  }
}

/// Whether [e] means "this email already belongs to a different account"
/// (as opposed to some unrelated failure that should just propagate).
/// Supabase's structured `code` is `email_exists`/`user_already_exists`
/// depending on server version — some older/self-hosted GoTrue responses
/// carry no `code` at all (`AuthException.code` is documented as
/// sometimes-null), so this also falls back to the message text rather than
/// risk mistaking "already registered" for an unrelated failure (network,
/// validation) and silently attempting the wrong recovery. A top-level
/// function (not a private method) so it's directly unit-testable without a
/// real `AuthApiException` round-trip from Supabase (CLAUDE.md §9).
bool isEmailAlreadyTakenError(AuthApiException e) =>
    e.code == 'email_exists' ||
    e.code == 'user_already_exists' ||
    e.message.toLowerCase().contains('already');
