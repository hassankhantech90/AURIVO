import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_exceptions.dart' as ex;
import '../../../core/supabase/supabase_service.dart';
import '../../../shared/design_system.dart';

/// A member of the owner's store team (`my_seller_staff()`).
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.canCatalog,
    required this.canOrders,
    this.revoked = false,
  });

  final String id;
  final String name;
  final String email;
  final bool canCatalog;
  final bool canOrders;
  final bool revoked;

  factory StaffMember.fromMap(Map<String, dynamic> m) => StaffMember(
    id: m['id'] as String,
    name: (m['full_name'] as String?)?.trim().isNotEmpty == true
        ? m['full_name'] as String
        : 'Team member',
    email: m['email'] as String? ?? '',
    canCatalog: m['can_catalog'] as bool? ?? false,
    canOrders: m['can_orders'] as bool? ?? false,
    revoked: m['revoked_at'] != null,
  );
}

/// Store-team RPCs (owner-only on the server).
class SellerTeamApi {
  const SellerTeamApi(this._database);

  final SupabaseDatabaseService _database;

  Future<List<StaffMember>> list() async {
    final rows = await _database.rpc(functionName: 'my_seller_staff');
    return [
      for (final r in (rows as List? ?? const []))
        StaffMember.fromMap(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> add(String email, {required bool catalog, required bool orders}) =>
      _database.rpc(
        functionName: 'add_seller_staff',
        params: {
          'p_email': email.trim(),
          'p_catalog': catalog,
          'p_orders': orders,
          'p_messages': false,
        },
      );

  Future<void> update(
    String staffId, {
    required bool catalog,
    required bool orders,
    bool revoke = false,
  }) => _database.rpc(
    functionName: 'update_seller_staff',
    params: {
      'p_staff_id': staffId,
      'p_catalog': catalog,
      'p_orders': orders,
      'p_messages': false,
      'p_revoke': revoke,
    },
  );
}

final sellerTeamApiProvider = Provider<SellerTeamApi>(
  (ref) => const SellerTeamApi(
    SupabaseDatabaseService(supabaseService: SupabaseService()),
  ),
);

final sellerTeamProvider = FutureProvider.autoDispose<List<StaffMember>>(
  (ref) => ref.watch(sellerTeamApiProvider).list(),
);

/// Seller Studio → Team (Requirements Doc §2 seller staff): the owner adds
/// existing Pareezay.Hub accounts by email with catalogue and/or orders access, and
/// can change or revoke it. Store settings, bank and payout details always
/// stay owner-only.
class SellerTeamPage extends ConsumerWidget {
  const SellerTeamPage({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      ref.invalidate(sellerTeamProvider);
      if (context.mounted) LuxurySnackBars.success(context, done);
    } catch (error) {
      if (context.mounted) LuxurySnackBars.error(context, _message(error));
    }
  }

  // The team RPCs raise buyer-readable messages (e.g. "No Pareezay.Hub account uses
  // that email"); surface them as-is.
  static String _message(Object error) =>
      error is ex.AppSupabaseException ? error.message : 'Something went wrong.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerTeamProvider);
    final api = ref.read(sellerTeamApiProvider);
    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Team', showBackButton: true),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add staff'),
        onPressed: () async {
          final input = await _AddStaffDialog.show(context);
          if (input == null || !context.mounted) return;
          await _run(
            context,
            ref,
            () => api.add(input.$1, catalog: input.$2, orders: input.$3),
            'Staff member added.',
          );
        },
      ),
      body: async.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load your team.',
          onRetry: () => ref.invalidate(sellerTeamProvider),
        ),
        data: (team) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            96,
          ),
          children: [
            Text(
              'Staff can manage your catalogue and/or orders. Store settings, '
              'bank and payout details stay with you.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (team.isEmpty)
              const EmptyStateWidget(
                title: 'No staff yet',
                message: 'Add a team member by the email they use on Pareezay.Hub.',
              ),
            for (final m in team)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: LuxuryCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (m.revoked) const LuxuryBadge(label: 'Revoked'),
                        ],
                      ),
                      Text(m.email, style: Theme.of(context).textTheme.bodySmall),
                      if (!m.revoked) ...[
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Catalogue'),
                          value: m.canCatalog,
                          onChanged: (v) => _run(
                            context,
                            ref,
                            () => api.update(m.id, catalog: v, orders: m.canOrders),
                            'Access updated.',
                          ),
                        ),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Orders & quotes'),
                          value: m.canOrders,
                          onChanged: (v) => _run(
                            context,
                            ref,
                            () => api.update(m.id, catalog: m.canCatalog, orders: v),
                            'Access updated.',
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: LuxuryTextButton(
                          label: m.revoked ? 'Restore access' : 'Revoke access',
                          onPressed: () => _run(
                            context,
                            ref,
                            () => api.update(
                              m.id,
                              catalog: m.revoked ? true : m.canCatalog,
                              orders: m.canOrders,
                              revoke: !m.revoked,
                            ),
                            m.revoked ? 'Access restored.' : 'Access revoked.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// (email, catalogue, orders) or null.
class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog();

  static Future<(String, bool, bool)?> show(BuildContext context) =>
      showDialog<(String, bool, bool)>(
        context: context,
        builder: (_) => const _AddStaffDialog(),
      );

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _email = TextEditingController();
  bool _catalog = true;
  bool _orders = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _email.text.contains('@') && (_catalog || _orders);
    return AlertDialog(
      title: const Text('Add staff'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Their Pareezay.Hub account email',
            ),
            onChanged: (_) => setState(() {}),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _catalog,
            title: const Text('Catalogue'),
            onChanged: (v) => setState(() => _catalog = v ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _orders,
            title: const Text('Orders & quotes'),
            onChanged: (v) => setState(() => _orders = v ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.of(context).pop((_email.text.trim(), _catalog, _orders))
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
