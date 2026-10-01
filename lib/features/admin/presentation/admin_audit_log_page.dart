import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/db_parsing.dart';
import '../../../shared/design_system.dart';
import '../../orders/presentation/order_formatting.dart';

/// One audit entry (`public.audit_logs`).
class AuditEntry {
  const AuditEntry({
    required this.seq,
    required this.table,
    required this.action,
    this.recordId,
    this.actorId,
    this.changedFields = const [],
    this.oldValues,
    this.newValues,
    this.createdAt,
  });

  final int seq;
  final String table;
  final String action;
  final String? recordId;
  final String? actorId;
  final List<String> changedFields;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final DateTime? createdAt;

  factory AuditEntry.fromMap(Map<String, dynamic> m) => AuditEntry(
    seq: parseInt(m['seq']),
    table: m['table_name'] as String,
    action: m['action'] as String,
    recordId: m['record_id'] as String?,
    actorId: m['performed_by'] as String?,
    changedFields: [for (final f in (m['changed_fields'] as List? ?? const [])) '$f'],
    oldValues: (m['old_values'] as Map?)?.cast<String, dynamic>(),
    newValues: (m['new_values'] as Map?)?.cast<String, dynamic>(),
    createdAt: parseTimestamp(m['created_at']),
  );
}

/// Audit groups shown as filter chips.
const auditGroups = <String, List<String>>{
  'All': [],
  'Approvals': ['seller_profiles', 'business_profiles', 'products'],
  'Finance': ['orders', 'payments', 'return_requests', 'disputes', 'coupons'],
  'Accounts & roles': ['profiles', 'profile_roles'],
  'Content': ['cms_pages', 'cms_banners'],
};

/// Data access for the audit screen (admin-only under RLS).
class AuditLogApi {
  const AuditLogApi(this._database);

  final SupabaseDatabaseService _database;

  Future<List<AuditEntry>> recent(List<String> tables) async {
    final rows = await _database.list(
      table: 'audit_logs',
      whereIn: {if (tables.isNotEmpty) 'table_name': List<Object>.from(tables)},
      orderBy: 'seq',
      ascending: false,
      limit: 150,
    );
    return rows.map(AuditEntry.fromMap).toList();
  }

  /// Null when the hash chain verifies, else the first broken entry's seq.
  Future<int?> verify() async {
    final result = await _database.rpc(functionName: 'verify_audit_chain');
    return result == null ? null : parseInt(result);
  }
}

final auditLogApiProvider = Provider<AuditLogApi>(
  (ref) => const AuditLogApi(
    SupabaseDatabaseService(supabaseService: SupabaseService()),
  ),
);

final auditEntriesProvider = FutureProvider.autoDispose
    .family<List<AuditEntry>, String>(
      (ref, group) =>
          ref.watch(auditLogApiProvider).recent(auditGroups[group] ?? const []),
    );

/// Admin audit log: recent approvals, finance, account/role and content
/// changes, with an integrity check of the tamper-evident hash chain.
class AdminAuditLogPage extends ConsumerStatefulWidget {
  const AdminAuditLogPage({super.key});

  @override
  ConsumerState<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends ConsumerState<AdminAuditLogPage> {
  String _group = 'All';
  bool _verifying = false;

  Future<void> _verify() async {
    setState(() => _verifying = true);
    try {
      final broken = await ref.read(auditLogApiProvider).verify();
      if (!mounted) return;
      broken == null
          ? LuxurySnackBars.success(context, 'Audit log verified — no tampering found.')
          : LuxurySnackBars.error(
              context,
              'Integrity check FAILED at entry #$broken. Investigate immediately.',
            );
    } catch (error) {
      if (mounted) LuxurySnackBars.error(context, 'Could not verify the audit log.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditEntriesProvider(_group));
    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Audit log',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Verify integrity',
            icon: _verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            onPressed: _verifying ? null : _verify,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              children: [
                for (final g in auditGroups.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: _group == g,
                      onSelected: (_) => setState(() => _group = g),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: LoadingIndicator()),
              error: (_, _) => ErrorStateWidget(
                message: 'Could not load the audit log.',
                onRetry: () => ref.invalidate(auditEntriesProvider(_group)),
              ),
              data: (entries) => entries.isEmpty
                  ? const EmptyStateWidget(
                      title: 'No entries',
                      message: 'Nothing has been recorded in this group yet.',
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(auditEntriesProvider(_group).future),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) => _EntryTile(entry: entries[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final AuditEntry entry;

  String _short(Object? v) {
    final s = v is String ? v : jsonEncode(v);
    return s.length > 40 ? '${s.substring(0, 40)}…' : s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    final lines = e.action == 'update'
        ? [
            for (final f in e.changedFields)
              '$f: ${_short(e.oldValues?[f])} → ${_short(e.newValues?[f])}',
          ]
        : <String>[];
    return LuxuryCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${e.table} · ${e.action}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text('#${e.seq}', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              if (e.createdAt != null) formatOrderDate(e.createdAt!),
              e.actorId == null ? 'system' : 'by ${e.actorId!.substring(0, 8)}',
              if (e.recordId != null) 'record ${e.recordId!.substring(0, 8)}',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          for (final line in lines) ...[
            const SizedBox(height: 2),
            Text(line, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
