import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../../orders/domain/entities/order_status.dart';
import '../../../orders/domain/entities/shipment.dart';
import '../../providers/seller_order_providers.dart';

/// Bottom-sheet form to create or update the shipment for a seller's order.
/// Submits through [sellerOrderDetailProvider]; returns `true` when saved.
class ShipmentFormSheet extends ConsumerStatefulWidget {
  const ShipmentFormSheet({super.key, required this.orderId, this.initial});

  final String orderId;
  final Shipment? initial;

  static Future<bool?> show(
    BuildContext context, {
    required String orderId,
    Shipment? initial,
  }) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => ShipmentFormSheet(orderId: orderId, initial: initial),
    );
  }

  @override
  ConsumerState<ShipmentFormSheet> createState() => _ShipmentFormSheetState();
}

class _ShipmentFormSheetState extends ConsumerState<ShipmentFormSheet> {
  late final TextEditingController _courier;
  late final TextEditingController _trackingNumber;
  late final TextEditingController _trackingUrl;
  late String _status;
  bool _submitting = false;
  String? _error;

  static const _statuses = <String>[
    ShipmentStatus.pending,
    ShipmentStatus.readyToShip,
    ShipmentStatus.shipped,
    ShipmentStatus.inTransit,
    ShipmentStatus.outForDelivery,
    ShipmentStatus.delivered,
    ShipmentStatus.failed,
    ShipmentStatus.returned,
    ShipmentStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _courier = TextEditingController(text: s?.courier ?? '');
    _trackingNumber = TextEditingController(text: s?.trackingNumber ?? '');
    _trackingUrl = TextEditingController(text: s?.trackingUrl ?? '');
    _status = s?.status ?? ShipmentStatus.pending;
  }

  @override
  void dispose() {
    _courier.dispose();
    _trackingNumber.dispose();
    _trackingUrl.dispose();
    super.dispose();
  }

  String? _opt(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref
        .read(sellerOrderDetailProvider(widget.orderId).notifier)
        .saveShipment(
          status: _status,
          courier: _opt(_courier),
          trackingNumber: _opt(_trackingNumber),
          trackingUrl: _opt(_trackingUrl),
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.initial == null ? 'Add shipment' : 'Update shipment',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: _statuses
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(ShipmentStatus.label(s)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _courier,
          labelText: 'Courier (optional)',
          hintText: 'e.g. TCS, Leopards',
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _trackingNumber,
          labelText: 'Tracking number (optional)',
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _trackingUrl,
          labelText: 'Tracking URL (optional)',
          keyboardType: TextInputType.url,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: LoadingButton(
            label: 'Save shipment',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
