import 'dart:async';

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

  final SupabaseAuthService _authService;
  StreamSubscription<supabase.AuthState>? _subscription;

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
      case supabase.AuthChangeEvent.initialSession:
      case supabase.AuthChangeEvent.signedIn:
      case supabase.AuthChangeEvent.tokenRefreshed:
      case supabase.AuthChangeEvent.userUpdated:
        final user = session?.user;
        state = user != null
            ? SessionState(status: SessionStatus.authenticated, user: user)
            : const SessionState(status: SessionStatus.unauthenticated);
      case supabase.AuthChangeEvent.signedOut:
        state = const SessionState(status: SessionStatus.unauthenticated);
      default:
        break;
    }
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
