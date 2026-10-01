import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/dispute.dart';
import '../providers/dispute_providers.dart';

/// Order-screen entry to the dispute centre for the buyer or a seller: opens a
/// dispute once the order has shipped, or links to the existing one.
class OrderDisputeEntry extends ConsumerWidget {
  const OrderDisputeEntry({
    super.key,
    required this.orderId,
    required this.orderStatus,
  });

  final String orderId;
  final String orderStatus;

  static const _eligible = {'shipped', 'delivered', 'completed', 'returned'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispute = ref.watch(orderDisputeProvider(orderId)).valueOrNull;
    final canOpen =
        _eligible.contains(orderStatus) && (dispute == null || !dispute.isOpen);
    if (dispute == null && !canOpen) return const SizedBox.shrink();

    Future<void> open() async {
      final input = await _OpenDisputeDialog.show(context);
      if (input == null || !context.mounted) return;
      try {
        final created = await ref
            .read(disputeRepositoryProvider)
            .openDispute(
              orderId: orderId,
              reason: input.$1,
              description: input.$2,
            );
        ref.invalidate(orderDisputeProvider(orderId));
        if (context.mounted) {
          context.push(AppRoutes.disputeDetailPath(created.id));
        }
      } catch (error) {
        if (context.mounted) LuxurySnackBars.error(context, error.toString());
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: dispute != null && dispute.isOpen
            ? LuxuryOutlinedButton(
                label: 'View dispute (open)',
                onPressed: () =>
                    context.push(AppRoutes.disputeDetailPath(dispute.id)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dispute != null)
                    LuxuryTextButton(
                      label: 'Previous dispute: ${dispute.statusLabel}',
                      onPressed: () =>
                          context.push(AppRoutes.disputeDetailPath(dispute.id)),
                    ),
                  LuxuryOutlinedButton(label: 'Open a dispute', onPressed: open),
                ],
              ),
      ),
    );
  }
}

/// (reasonCode, description) or null.
class _OpenDisputeDialog extends StatefulWidget {
  const _OpenDisputeDialog();

  static Future<(String, String)?> show(BuildContext context) =>
      showDialog<(String, String)>(
        context: context,
        builder: (_) => const _OpenDisputeDialog(),
      );

  @override
  State<_OpenDisputeDialog> createState() => _OpenDisputeDialogState();
}

class _OpenDisputeDialogState extends State<_OpenDisputeDialog> {
  String _reason = Dispute.reasons.keys.first;
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Open a dispute'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final e in Dispute.reasons.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                helperText: 'You can add photos as evidence in the dispute.',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _description.text.trim().isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop((_reason, _description.text.trim())),
          child: const Text('Open dispute'),
        ),
      ],
    );
  }
}
