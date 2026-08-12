import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../../wholesale/domain/entities/quote.dart';
import '../../domain/entities/quote_draft.dart';
import '../../providers/seller_rfq_providers.dart';

/// Modal bottom-sheet form for a seller to create or edit their quote against
/// an RFQ. Submits through [sellerRfqDetailProvider]. Returns `true` when saved.
class QuoteFormSheet extends ConsumerStatefulWidget {
  const QuoteFormSheet({super.key, required this.rfqId, this.initial});

  final String rfqId;
  final Quote? initial;

  static Future<bool?> show(
    BuildContext context, {
    required String rfqId,
    Quote? initial,
  }) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => QuoteFormSheet(rfqId: rfqId, initial: initial),
    );
  }

  @override
  ConsumerState<QuoteFormSheet> createState() => _QuoteFormSheetState();
}

class _QuoteFormSheetState extends ConsumerState<QuoteFormSheet> {
  late final TextEditingController _unitPrice;
  late final TextEditingController _totalPrice;
  late final TextEditingController _moq;
  late final TextEditingController _leadTime;
  late final TextEditingController _message;
  String _currency = 'PKR';
  String _status = 'sent';
  DateTime? _validUntil;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _unitPrice = TextEditingController(text: q?.unitPrice.toString() ?? '');
    _totalPrice = TextEditingController(text: q?.totalPrice.toString() ?? '');
    _moq = TextEditingController(
      text: q?.minimumOrderQuantity.toString() ?? '1',
    );
    _leadTime = TextEditingController(text: q?.leadTimeDays?.toString() ?? '');
    _message = TextEditingController(text: q?.message ?? '');
    _currency = q?.currency ?? 'PKR';
    _status = (q?.status == 'draft' || q?.status == 'withdrawn')
        ? q!.status
        : 'sent';
    _validUntil = q?.validUntil;
  }

  @override
  void dispose() {
    for (final c in [_unitPrice, _totalPrice, _moq, _leadTime, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _submit() async {
    final unit = double.tryParse(_unitPrice.text.trim());
    final total = double.tryParse(_totalPrice.text.trim());
    final moq = int.tryParse(_moq.text.trim()) ?? 1;
    if (unit == null || unit < 0 || total == null || total < 0 || moq < 1) {
      setState(() => _error = 'Enter a valid unit price, total and MOQ.');
      return;
    }
    if (total < unit * moq) {
      setState(
        () => _error =
            'Total must be at least unit price × MOQ '
            '(${(unit * moq).toStringAsFixed(2)}).',
      );
      return;
    }

    final draft = QuoteDraft(
      unitPrice: unit,
      totalPrice: total,
      minimumOrderQuantity: moq,
      currency: _currency,
      leadTimeDays: int.tryParse(_leadTime.text.trim()),
      validUntil: _validUntil,
      message: _message.text,
      status: _status,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref
        .read(sellerRfqDetailProvider(widget.rfqId).notifier)
        .submitQuote(draft);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEditing ? 'Edit quote' : 'Send a quote',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _unitPrice,
                labelText: 'Unit price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: const [
                  DropdownMenuItem(value: 'PKR', child: Text('PKR')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'PKR'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _moq,
                labelText: 'Min order qty',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomTextField(
                controller: _totalPrice,
                labelText: 'Total price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _leadTime,
          labelText: 'Lead time (days, optional)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                _validUntil == null
                    ? 'Valid until: not set'
                    : 'Valid until: ${_validUntil!.toLocal().toString().split(' ').first}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            LuxuryTextButton(label: 'Pick date', onPressed: _pickValidUntil),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: const [
            DropdownMenuItem(value: 'draft', child: Text('Draft')),
            DropdownMenuItem(value: 'sent', child: Text('Sent')),
            DropdownMenuItem(value: 'withdrawn', child: Text('Withdrawn')),
          ],
          onChanged: (v) => setState(() => _status = v ?? 'sent'),
        ),
        const SizedBox(height: AppSpacing.md),
        MultilineTextField(
          controller: _message,
          labelText: 'Message (optional)',
          minLines: 2,
          maxLines: 5,
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
            label: _isEditing ? 'Save quote' : 'Send quote',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
