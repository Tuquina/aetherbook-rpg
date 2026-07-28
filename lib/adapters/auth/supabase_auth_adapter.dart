import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ports/auth_port.dart';

/// Wraps Supabase Auth (CLAUDE.md §4/§8: the only file that talks to
/// `supabase_flutter`'s `auth` surface directly). Owns the whole identity
/// lifecycle — Google or email+password (V2 — see `AuthPort`'s doc comment
/// for why magic-link was discontinued, and why there's no anonymous
/// bootstrap here: a real account is required before any session exists).
class SupabaseAuthAdapter implements AuthPort {
  SupabaseAuthAdapter(this._client, {this.emailRedirectTo});

  final SupabaseClient _client;

  /// Where Supabase redirects the player after an OAuth consent screen or a
  /// password-reset email — must be allow-listed in the project's
  /// Auth > URL Configuration. `null` falls back to the project's
  /// configured Site URL.
  final String? emailRedirectTo;

  GoTrueClient get _auth => _client.auth;

  @override
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  DateTime? get accountCreatedAt {
    final raw = _auth.currentUser?.createdAt;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Stream<void> get onChange => _auth.onAuthStateChange;

  @override
  Future<void> signInWithGoogle() {
    // signInWithOAuth, not linkIdentity: there's no anonymous session to
    // attach to anymore — this creates (or signs into) a real account
    // directly.
    return _auth.signInWithOAuth(OAuthProvider.google, redirectTo: emailRedirectTo);
  }

  @override
  Future<void> signUpWithPassword({required String email, required String password}) async {
    try {
      await _auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
      );
    } on AuthApiException catch (e) {
      if (isEmailAlreadyTakenError(e)) {
        throw EmailAlreadyRegisteredException(email);
      }
      rethrow;
    }
  }

  @override
  Future<void> signInWithPassword({required String email, required String password}) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> resetPassword(String email) {
    return _auth.resetPasswordForEmail(email, redirectTo: emailRedirectTo);
  }

  @override
  Future<void> signOut() => _auth.signOut();
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
