import 'package:aurivo/core/supabase/supabase_auth_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:aurivo/features/support/domain/entities/support_ticket.dart';
import 'package:aurivo/features/support/domain/repositories/support_repository.dart';
import 'package:aurivo/features/support/presentation/admin_support_detail_page.dart';
import 'package:aurivo/features/support/presentation/support_page.dart';
import 'package:aurivo/features/support/providers/support_providers.dart';
import 'package:aurivo/shared/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthedSession extends SessionNotifier {
  _AuthedSession()
    : super(
        authService: const SupabaseAuthService(
          supabaseService: SupabaseService(),
        ),
      ) {
    state = const SessionState(status: SessionStatus.authenticated);
  }
}

SupportTicket _t(String id, {String status = 'open'}) => SupportTicket(
  id: id,
  profileId: 'me',
  subject: 'Subject $id',
  description: 'A sufficiently long description here.',
  category: 'order',
  status: status,
);

class _FakeRepo implements SupportRepository {
  _FakeRepo(this._items);
  List<SupportTicket> _items;
  final List<String> log = [];

  @override
  Future<List<SupportTicket>> list({String? status}) async => _items;

  @override
  Future<SupportTicket> create({
    required String subject,
    required String description,
    String category = 'general',
    String priority = 'normal',
    String? orderId,
  }) async {
    log.add('create:$subject');
    final t = _t('new');
    _items = [t, ..._items];
    return t;
  }

  @override
  Future<void> assignToMe(String id) async => log.add('assign:$id');

  @override
  Future<void> setStatus({required String id, required String status}) async {
    log.add('status:$id:$status');
    _items = _items.map((t) => t.id == id ? _t(id, status: status) : t).toList();
  }
}

Widget _wrap(List<Override> overrides, Widget page) =>
    ProviderScope(overrides: overrides, child: MaterialApp(home: page));

void main() {
  testWidgets('guests are prompted to sign in', (tester) async {
    await tester.pumpWidget(
      _wrap(
        [supportRepositoryProvider.overrideWithValue(_FakeRepo([]))],
        const SupportPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to contact support'), findsOneWidget);
  });

  testWidgets('user sees their tickets', (tester) async {
    await tester.pumpWidget(
      _wrap(
        [
          supportRepositoryProvider.overrideWithValue(
            _FakeRepo([_t('1'), _t('2', status: 'resolved')]),
          ),
          sessionProvider.overrideWith((ref) => _AuthedSession()),
        ],
        const SupportPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subject 1'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
  });

  testWidgets('admin detail assigns and changes status', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo([_t('1')]);
    await tester.pumpWidget(
      _wrap(
        [supportRepositoryProvider.overrideWithValue(repo)],
        const AdminSupportDetailPage(ticketId: '1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(LuxuryOutlinedButton, 'Assign to me'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('assign:1'));

    await tester.tap(find.widgetWithText(LuxuryChip, 'Resolved'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('status:1:resolved'));
  });
}
