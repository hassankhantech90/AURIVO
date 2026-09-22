import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/admin/domain/repositories/admin_repository.dart';
import 'package:aurivo/features/admin/providers/admin_providers.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// Minimal AdminRepository: only isAdmin() is exercised here; it records calls
/// and returns a settable result.
class _FakeAdminRepo implements AdminRepository {
  _FakeAdminRepo(this._result);
  bool _result;
  int isAdminCalls = 0;
  set result(bool v) => _result = v;

  @override
  Future<bool> isAdmin() async {
    isAdminCalls++;
    return _result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSession extends SessionNotifier {
  _TestSession()
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      );
  void set(SessionState next) => state = next;
}

SessionState _authAs(String userId) => SessionState(
  status: SessionStatus.authenticated,
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026).toIso8601String(),
  ),
);

const SessionState _guest = SessionState(status: SessionStatus.unauthenticated);

ProviderContainer _container(_FakeAdminRepo repo, _TestSession session) {
  final container = ProviderContainer(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      sessionProvider.overrideWith((ref) => session),
    ],
  );
  addTearDown(container.dispose);
  // Keep the async provider alive so it rebuilds on session changes.
  container.listen(isAdminProvider, (_, _) {});
  return container;
}

void main() {
  test('isAdminProvider is false when signed out, without hitting the RPC', () async {
    final repo = _FakeAdminRepo(true);
    final session = _TestSession()..set(_guest);
    final container = _container(repo, session);

    expect(await container.read(isAdminProvider.future), isFalse);
    expect(repo.isAdminCalls, 0); // short-circuited: no has_role RPC
  });

  test('isAdminProvider reflects the current user', () async {
    final repo = _FakeAdminRepo(true);
    final session = _TestSession()..set(_authAs('admin-user'));
    final container = _container(repo, session);

    expect(await container.read(isAdminProvider.future), isTrue);
  });

  test('isAdminProvider recomputes on account switch (no stale admin leak)', () async {
    final repo = _FakeAdminRepo(true); // signed-in admin
    final session = _TestSession()..set(_authAs('admin-user'));
    final container = _container(repo, session);

    expect(await container.read(isAdminProvider.future), isTrue);

    // Switch to a different (non-admin) identity: must recompute to false,
    // never reuse the cached admin=true.
    repo.result = false;
    session.set(_authAs('buyer-user'));

    expect(await container.read(isAdminProvider.future), isFalse);
  });
}
