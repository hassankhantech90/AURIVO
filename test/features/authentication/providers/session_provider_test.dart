import 'dart:async';

import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Drives SessionNotifier's recovery state machine through synthetic Supabase
/// auth events. `_recovering` is intentionally private — these tests assert only
/// the OBSERVABLE app-level session state (isAuthenticated).

const _authService = SupabaseAuthService(supabaseService: SupabaseService());

supabase.User _user() => supabase.User(
  id: 'u1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2020-01-01T00:00:00Z',
);

supabase.Session _session() =>
    supabase.Session(accessToken: 'token', tokenType: 'bearer', user: _user());

supabase.AuthState _evt(
  supabase.AuthChangeEvent event, {
  supabase.Session? session,
}) => supabase.AuthState(event, session);

/// Mirrors PushBootstrap's documented transition rule: register on a
/// unauthenticated->authenticated transition, unregister on the reverse. (In
/// production PushBootstrap additionally gates on _messagingReady and calls the
/// real registrar; both are unchanged by this commit.)
({int register, int unregister}) _pushCalls(List<bool> flags) {
  var register = 0;
  var unregister = 0;
  var wasAuth = false;
  for (final isAuth in flags) {
    if (!wasAuth && isAuth) {
      register++;
    } else if (wasAuth && !isAuth) {
      unregister++;
    }
    wasAuth = isAuth;
  }
  return (register: register, unregister: unregister);
}

void main() {
  late StreamController<supabase.AuthState> controller;
  late SessionNotifier notifier;
  late List<bool> authFlags;

  setUp(() {
    controller = StreamController<supabase.AuthState>.broadcast();
    notifier = SessionNotifier.forTest(
      authEvents: controller.stream,
      authService: _authService,
    );
    authFlags = [];
    // fireImmediately delivers the initial (unauthenticated) state.
    notifier.addListener((s) => authFlags.add(s.isAuthenticated));
  });

  tearDown(() async {
    notifier.dispose();
    await controller.close();
  });

  Future<void> emit(
    supabase.AuthChangeEvent event, {
    supabase.Session? session,
  }) async {
    controller.add(_evt(event, session: session));
    await Future<void>.delayed(Duration.zero);
  }

  group('recovery state machine', () {
    test('passwordRecovery keeps the app unauthenticated', () async {
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());

      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('userUpdated during recovery does not authenticate', () async {
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());
      await emit(supabase.AuthChangeEvent.userUpdated, session: _session());

      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('tokenRefreshed during recovery does not authenticate', () async {
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());
      await emit(supabase.AuthChangeEvent.tokenRefreshed, session: _session());

      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('signedOut clears recovery and stays unauthenticated', () async {
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());
      await emit(supabase.AuthChangeEvent.signedOut);
      expect(notifier.state.isAuthenticated, isFalse);

      // Recovery cleared: a later userUpdated is no longer suppressed.
      await emit(supabase.AuthChangeEvent.userUpdated, session: _session());
      expect(notifier.state.isAuthenticated, isTrue);
    });

    test('genuine signedIn clears recovery and authenticates', () async {
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());
      expect(notifier.state.isAuthenticated, isFalse);

      await emit(supabase.AuthChangeEvent.signedIn, session: _session());
      expect(notifier.state.isAuthenticated, isTrue);

      // Recovery cleared: a later tokenRefreshed keeps the user authenticated.
      await emit(supabase.AuthChangeEvent.tokenRefreshed, session: _session());
      expect(notifier.state.isAuthenticated, isTrue);
    });
  });

  group('normal (non-recovery) behavior unchanged', () {
    test('userUpdated outside recovery authenticates', () async {
      await emit(supabase.AuthChangeEvent.userUpdated, session: _session());
      expect(notifier.state.isAuthenticated, isTrue);
    });

    test('tokenRefreshed outside recovery authenticates', () async {
      await emit(supabase.AuthChangeEvent.tokenRefreshed, session: _session());
      expect(notifier.state.isAuthenticated, isTrue);
    });

    test('initialSession authenticates with a session, not without', () async {
      await emit(supabase.AuthChangeEvent.initialSession, session: _session());
      expect(notifier.state.isAuthenticated, isTrue);

      await emit(supabase.AuthChangeEvent.initialSession, session: null);
      expect(notifier.state.isAuthenticated, isFalse);
    });
  });

  group('terminal lingering recovery state is benign', () {
    test('app stays unauthenticated after a suppressed update with no '
        'signedOut', () async {
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());
      // Terminal update failure emits no signedOut; a prior suppressed
      // userUpdated leaves _recovering lingering.
      await emit(supabase.AuthChangeEvent.userUpdated, session: _session());

      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('a later genuine signedIn still recovers to authenticated', () async {
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());
      await emit(supabase.AuthChangeEvent.userUpdated, session: _session());
      // Lingering _recovering must not block a real login.
      await emit(supabase.AuthChangeEvent.signedIn, session: _session());

      expect(notifier.state.isAuthenticated, isTrue);
    });

    test('a later signedOut clears and stays unauthenticated', () async {
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());
      await emit(supabase.AuthChangeEvent.userUpdated, session: _session());
      await emit(supabase.AuthChangeEvent.signedOut);

      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('a fresh notifier does not carry recovery lifecycle', () async {
      // First notifier enters recovery.
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());

      final c2 = StreamController<supabase.AuthState>.broadcast();
      final n2 = SessionNotifier.forTest(
        authEvents: c2.stream,
        authService: _authService,
      );
      c2.add(_evt(supabase.AuthChangeEvent.userUpdated, session: _session()));
      await Future<void>.delayed(Duration.zero);

      // Fresh instance is not recovering, so userUpdated authenticates.
      expect(n2.state.isAuthenticated, isTrue);

      n2.dispose();
      await c2.close();
    });
  });

  group('push invariant (via session transitions)', () {
    test('recovery sequence causes zero push register/unregister', () async {
      await emit(supabase.AuthChangeEvent.passwordRecovery, session: _session());
      await emit(supabase.AuthChangeEvent.tokenRefreshed, session: _session());
      await emit(supabase.AuthChangeEvent.userUpdated, session: _session());
      await emit(supabase.AuthChangeEvent.signedOut);

      // Never authenticated across the whole sequence.
      expect(authFlags.any((a) => a), isFalse);
      final calls = _pushCalls(authFlags);
      expect(calls.register, 0);
      expect(calls.unregister, 0);
    });

    test('a normal sign-in triggers exactly one register', () async {
      await emit(supabase.AuthChangeEvent.signedIn, session: _session());

      final calls = _pushCalls(authFlags);
      expect(calls.register, 1);
      expect(calls.unregister, 0);
    });

    test('a normal sign-in then sign-out triggers one register and one '
        'unregister', () async {
      await emit(supabase.AuthChangeEvent.signedIn, session: _session());
      await emit(supabase.AuthChangeEvent.signedOut);

      final calls = _pushCalls(authFlags);
      expect(calls.register, 1);
      expect(calls.unregister, 1);
    });
  });
}
