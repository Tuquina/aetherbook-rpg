import 'dart:async';

import '../../ports/auth_port.dart';

// prefer_initializing_formals is disabled for `_email` below: the field is
// private and Dart forbids private *named* parameters, so `this._email`
// would make the label inaccessible to callers outside this file (see the
// same note in game_controller.dart).
// ignore_for_file: prefer_initializing_formals

/// In-memory fake of [AuthPort] for tests (CLAUDE.md §9) — never touches
/// Supabase. Records every [continueWithEmail] call so tests can assert on
/// it, and exposes [simulateLinked] to fake the player clicking the emailed
/// confirmation link without a real redirect round-trip.
class FakeAuthAdapter implements AuthPort {
  FakeAuthAdapter({bool anonymous = true, String? email})
      : _isAnonymous = anonymous,
        _email = email;

  bool _isAnonymous;
  String? _email;

  final List<String> continueWithEmailCalls = [];

  /// What the next [continueWithEmail] call returns — set by a test to
  /// exercise either branch without a real provider response.
  EmailLinkOutcome nextOutcome = EmailLinkOutcome.linkConfirmationSent;

  /// Set by a test to make the next [continueWithEmail] call throw instead.
  Object? nextError;

  final _controller = StreamController<void>.broadcast();

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  String? get email => _email;

  @override
  Stream<void> get onChange => _controller.stream;

  @override
  Future<EmailLinkOutcome> continueWithEmail(String email) async {
    continueWithEmailCalls.add(email);
    final error = nextError;
    if (error != null) throw error;
    return nextOutcome;
  }

  /// Fakes the player having opened the confirmation/sign-in link.
  void simulateLinked(String email) {
    _isAnonymous = false;
    _email = email;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
