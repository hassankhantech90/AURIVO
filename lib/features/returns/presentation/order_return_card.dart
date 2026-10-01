import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system.dart';
import '../domain/entities/return_request.dart';
import '../providers/return_providers.dart';

/// Who is looking at the order — decides which return actions are offered.
/// The server enforces the same rules; this only hides impossible buttons.
enum ReturnViewer {
  buyer,
  seller,
  admin,
  support,
  finance;

  /// May approve / decline / mark received (seller, admin, support).
  bool get canDecide => this == seller || this == admin || this == support;

  /// May record the refund (admin, finance).
  bool get canRefund => this == admin || this == finance;
}

/// Return status + actions for one order, shared by the buyer, seller and
/// admin order screens. [onChanged] lets the host reload the order after a
/// transition that changes its status (received -> returned, refunded).
class OrderReturnCard extends ConsumerWidget {
  const OrderReturnCard({
    super.key,
    required this.orderId,
    required this.orderStatus,
    required this.viewer,
    this.onChanged,
  });

  final String orderId;
  final String orderStatus;
  final ReturnViewer viewer;
  final VoidCallback? onChanged;

  bool get _delivered =>
      orderStatus == 'delivered' || orderStatus == 'completed';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(orderReturnProvider(orderId)).valueOrNull;
    final canRequest =
        viewer == ReturnViewer.buyer &&
        _delivered &&
        (request == null || !request.isOpen);

    if (request == null && !canRequest) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: LuxuryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Returns', style: theme.textTheme.titleSmall),
            if (request != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(request.statusLabel, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Reason: ${request.reasonLabel}'
                '${request.details == null ? '' : ' — ${request.details}'}',
                style: theme.textTheme.bodySmall,
              ),
              if (request.resolutionNote != null)
                Text(
                  'Note: ${request.resolutionNote}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
            ..._actions(context, ref, request, canRequest),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    ReturnRequest? request,
    bool canRequest,
  ) {
    final notifier = ref.read(orderReturnProvider(orderId).notifier);

    Future<void> run(Future<String?> action, String success) async {
      final error = await action;
      if (!context.mounted) return;
      if (error != null) {
        LuxurySnackBars.error(context, error);
      } else {
        LuxurySnackBars.success(context, success);
        onChanged?.call();
      }
    }

    Widget button(String label, VoidCallback onPressed, {bool primary = false}) =>
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: SizedBox(
            width: double.infinity,
            child: primary
                ? PrimaryButton(label: label, onPressed: onPressed)
                : LuxuryOutlinedButton(label: label, onPressed: onPressed),
          ),
        );

    if (canRequest) {
      return [
        button('Request a return', () async {
          final input = await _ReturnRequestDialog.show(context);
          if (input == null) return;
          await run(
            notifier.request(reason: input.$1, details: input.$2),
            'Return requested. The seller will review it.',
          );
        }),
      ];
    }
    if (request == null) return const [];

    final isStaff = viewer.canDecide;
    return [
      if (viewer == ReturnViewer.buyer && request.status == ReturnRequest.requested)
        button(
          'Withdraw return',
          () => run(notifier.cancel(request.id), 'Return withdrawn.'),
        ),
      if (isStaff && request.status == ReturnRequest.requested) ...[
        button(
          'Approve return',
          () => run(
            notifier.decide(request.id, approve: true),
            'Return approved.',
          ),
          primary: true,
        ),
        button('Decline return', () async {
          final note = await _NoteDialog.show(
            context,
            title: 'Decline return',
            hint: 'Reason for the buyer (required)',
          );
          if (note == null) return;
          await run(
            notifier.decide(request.id, approve: false, note: note),
            'Return declined.',
          );
        }),
      ],
      if (isStaff && request.status == ReturnRequest.approved)
        button(
          'Mark item received',
          () => run(notifier.markReceived(request.id), 'Return received.'),
          primary: true,
        ),
      if (viewer.canRefund && request.status == ReturnRequest.received)
        button('Record refund', () async {
          final note = await _NoteDialog.show(
            context,
            title: 'Record refund',
            hint: 'How was it refunded? (optional)',
            optional: true,
          );
          if (note == null) return;
          await run(
            notifier.markRefunded(request.id, note: note.isEmpty ? null : note),
            'Refund recorded.',
          );
        }, primary: true),
    ];
  }
}

/// Reason + optional details. Returns (reasonCode, details) or null.
class _ReturnRequestDialog extends StatefulWidget {
  const _ReturnRequestDialog();

  static Future<(String, String?)?> show(BuildContext context) =>
      showDialog<(String, String?)>(
        context: context,
        builder: (_) => const _ReturnRequestDialog(),
      );

  @override
  State<_ReturnRequestDialog> createState() => _ReturnRequestDialogState();
}

class _ReturnRequestDialogState extends State<_ReturnRequestDialog> {
  String _reason = ReturnRequest.reasons.keys.first;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request a return'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [
              for (final e in ReturnRequest.reasons.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _details,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Returns are accepted within 7 days of delivery.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final details = _details.text.trim();
            Navigator.of(context).pop((_reason, details.isEmpty ? null : details));
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

/// Single free-text note. Returns the trimmed text ('' allowed when
/// [optional]) or null when cancelled.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.hint,
    this.optional = false,
  });

  final String title;
  final String hint;
  final bool optional;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hint,
    bool optional = false,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(title: title, hint: hint, optional: optional),
  );

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _note,
        maxLines: 3,
        decoration: InputDecoration(hintText: widget.hint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !widget.optional && _note.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_note.text.trim()),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
