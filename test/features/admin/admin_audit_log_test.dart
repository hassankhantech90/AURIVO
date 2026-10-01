import 'package:aurivo/core/supabase/supabase_database_service.dart';
import 'package:aurivo/core/supabase/supabase_service.dart';
import 'package:aurivo/features/admin/presentation/admin_audit_log_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends AuditLogApi {
  _FakeApi({this.broken})
    : super(const SupabaseDatabaseService(supabaseService: SupabaseService()));

  final int? broken;
  final List<List<String>> queries = [];

  @override
  Future<List<AuditEntry>> recent(List<String> tables) async {
    queries.add(tables);
    return [
      AuditEntry.fromMap({
        'seq': 7,
        'table_name': 'products',
        'action': 'update',
        'record_id': '3dba6b4f-1391-4633-aebf-e15cde7e7a9d',
        'performed_by': '1dd34c4a-623d-40ff-8632-b94e554da9d4',
        'changed_fields': ['status'],
        'old_values': {'status': 'pending'},
        'new_values': {'status': 'approved'},
        'created_at': '2026-10-02T10:00:00Z',
      }),
    ];
  }

  @override
  Future<int?> verify() async => broken;
}

Future<void> _pump(WidgetTester tester, _FakeApi api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [auditLogApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: AdminAuditLogPage()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows entries with field diffs and filters by group', (
    tester,
  ) async {
    final api = _FakeApi();
    await _pump(tester, api);

    expect(find.text('products · update'), findsOneWidget);
    expect(find.text('status: pending → approved'), findsOneWidget);
    expect(api.queries.last, isEmpty); // All

    await tester.tap(find.text('Finance'));
    await tester.pump();
    await tester.pump();
    expect(api.queries.last, contains('payments'));
  });

  testWidgets('verify reports a clean chain', (tester) async {
    await _pump(tester, _FakeApi());
    await tester.tap(find.byTooltip('Verify integrity'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('no tampering found'), findsOneWidget);
  });

  testWidgets('verify flags the first broken entry', (tester) async {
    await _pump(tester, _FakeApi(broken: 3));
    await tester.tap(find.byTooltip('Verify integrity'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('FAILED at entry #3'), findsOneWidget);
  });
}
