import 'dart:async';

import '../../ports/auth_port.dart';

// prefer_initializing_formals is disabled for `_email` below: the field is
// private and Dart forbids private *named* parameters, so `this._email`
// would make the label inaccessible to callers outside this file (same note
// as game_controller.dart).
// ignore_for_file: prefer_initializing_formals

/// In-memory fake of [AuthPort] for tests (CLAUDE.md §9) — never touches
/// Supabase. Records every call so tests can assert on it, and exposes
/// [simulateEmailConfirmed] to fake the player clicking a confirmation
/// email without a real redirect round-trip.
class FakeAuthAdapter implements AuthPort {
  FakeAuthAdapter({bool anonymous = true, String? email})
      : _isAnonymous = anonymous,
        _email = email;

  bool _isAnonymous;
  String? _email;

  final List<void> signInWithGoogleCalls = [];
  final List<({String email, String password})> signUpWithPasswordCalls = [];
  final List<({String email, String password})> signInWithPasswordCalls = [];
  final List<String> resetPasswordCalls = [];

  /// Set by a test to make the *next* call throw instead of succeeding —
  /// checked once, then cleared, so a test can make one call fail and a
  /// following retry succeed without extra bookkeeping.
  Object? nextError;

  final _controller = StreamController<void>.broadcast();

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  String? get email => _email;

  @override
  Stream<void> get onChange => _controller.stream;

  Object? _takeNextError() {
    final error = nextError;
    nextError = null;
    return error;
  }

  @override
  Future<void> signInWithGoogle() async {
    signInWithGoogleCalls.add(null);
    final error = _takeNextError();
    if (error != null) throw error;
    // Real linkIdentity() only launches the consent screen; completion
    // arrives later via onChange (see AuthPort.signInWithGoogle's doc
    // comment) — simulated here as happening synchronously since there's no
    // real browser round trip to wait for in a fake.
    _isAnonymous = false;
    _email = 'jugador@gmail.com';
    _controller.add(null);
  }

  @override
  Future<void> signUpWithPassword({required String email, required String password}) async {
    signUpWithPasswordCalls.add((email: email, password: password));
    final error = _takeNextError();
    if (error != null) throw error;
    // Deliberately does NOT flip isAnonymous — real Supabase Auth requires
    // confirming the emailed link first (see simulateEmailConfirmed).
  }

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    signInWithPasswordCalls.add((email: email, password: password));
    final error = _takeNextError();
    if (error != null) throw error;
    _isAnonymous = false;
    _email = email;
    _controller.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {
    resetPasswordCalls.add(email);
    final error = _takeNextError();
    if (error != null) throw error;
  }

  /// Fakes the player having confirmed the emailed link after
  /// [signUpWithPassword] — that's the only real-world way a signed-up
  /// account actually stops being anonymous.
  void simulateEmailConfirmed(String email) {
    _isAnonymous = false;
    _email = email;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
