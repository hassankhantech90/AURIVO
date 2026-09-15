import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_service.dart';

/// Lifecycle status of the current authentication session.
enum SessionStatus { unknown, authenticated, unauthenticated }

/// Synchronized snapshot of the current Supabase auth session.
class SessionState {
  const SessionState({this.status = SessionStatus.unknown, this.user});

  final SessionStatus status;
  final supabase.User? user;

  bool get isAuthenticated => status == SessionStatus.authenticated;
}

/// Exposes the current session and keeps it synchronized with Supabase Auth.
///
/// Auto-logs-in when a persisted session exists, auto-logs-out when the session
/// ends or expires, and reacts to every Supabase auth event.
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((
  ref,
) {
  return SessionNotifier(
    authService: const SupabaseAuthService(supabaseService: SupabaseService()),
  );
});

/// Whether a Supabase session is currently restored/active. A small read-only
/// seam over [sessionProvider] so startup routing (Splash) can decide Home vs
/// Login and be unit-tested by overriding just this value. The session is
/// restored before `runApp` (main awaits Supabase init), so this is accurate at
/// first read — no restoration race.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).isAuthenticated;
});

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier({required SupabaseAuthService authService})
    : _authService = authService,
      super(const SessionState()) {
    _initialize();
  }

  /// Test-only seam: drive the notifier from an explicit auth-event stream
  /// without requiring Supabase configuration, so the recovery state machine can
  /// be exercised. Production always uses the default constructor; `_recovering`
  /// starts false and is never persisted across recreation.
  @visibleForTesting
  SessionNotifier.forTest({
    required Stream<supabase.AuthState> authEvents,
    required SupabaseAuthService authService,
    SessionState initial = const SessionState(
      status: SessionStatus.unauthenticated,
    ),
  }) : _authService = authService,
       super(initial) {
    _subscription = authEvents.listen(_onAuthStateChanged);
  }

  final SupabaseAuthService _authService;
  StreamSubscription<supabase.AuthState>? _subscription;

  // Transient recovery-lifecycle flag — NOT security authorization (that is the
  // repository's isRecoveryAuthorized). It only suppresses the app-level
  // authenticated transition (and thus push registration) while a recovery
  // session is active, so verifyOTP(recovery) -> updateUser -> signOut never
  // looks like a login. In-memory only; never persisted.
  bool _recovering = false;

  void _initialize() {
    // Without Supabase credentials there is no session to synchronize.
    if (!SupabaseConfig.isConfigured) {
      state = const SessionState(status: SessionStatus.unauthenticated);
      return;
    }

    final user = _authService.currentUser;
    state = user != null
        ? SessionState(status: SessionStatus.authenticated, user: user)
        : const SessionState(status: SessionStatus.unauthenticated);

    _subscription = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(supabase.AuthState data) {
    final session = data.session;
    switch (data.event) {
      case supabase.AuthChangeEvent.passwordRecovery:
        // A recovery session now exists in the SDK, but the app must NOT treat
        // it as a login: stay unauthenticated so push never registers. The
        // permission to reset lives solely in the repository.
        _recovering = true;
        state = const SessionState(status: SessionStatus.unauthenticated);
      case supabase.AuthChangeEvent.userUpdated:
      case supabase.AuthChangeEvent.tokenRefreshed:
        // During recovery, suppress the authenticated transition — the recovery
        // session's updateUser (success path) and background auto-refresh must
        // not look like a login. Outside recovery, behave exactly as before.
        if (_recovering) {
          state = const SessionState(status: SessionStatus.unauthenticated);
        } else {
          _applySession(session);
        }
      case supabase.AuthChangeEvent.signedIn:
        // A genuine sign-in ends any recovery lifecycle and authenticates.
        _recovering = false;
        _applySession(session);
      case supabase.AuthChangeEvent.initialSession:
        // Cold-start restore: normal behavior. `_recovering` is always false
        // here (in-memory, never carried across provider recreation).
        _applySession(session);
      case supabase.AuthChangeEvent.signedOut:
        _recovering = false;
        state = const SessionState(status: SessionStatus.unauthenticated);
      default:
        break;
    }
  }

  void _applySession(supabase.Session? session) {
    final user = session?.user;
    state = user != null
        ? SessionState(status: SessionStatus.authenticated, user: user)
        : const SessionState(status: SessionStatus.unauthenticated);
  }

  /// Signs the user out and clears the synchronized session state.
  Future<void> signOut() async {
    await _authService.signOut();
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
