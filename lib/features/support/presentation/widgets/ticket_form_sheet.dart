import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system.dart';
import '../../domain/entities/support_ticket.dart';
import '../../providers/support_providers.dart';

/// New-ticket form. Submits through [ticketsProvider]; returns `true` when saved.
class TicketFormSheet extends ConsumerStatefulWidget {
  const TicketFormSheet({super.key, this.orderId});

  final String? orderId;

  static Future<bool?> show(BuildContext context, {String? orderId}) {
    return LuxuryBottomSheet.show<bool>(
      context: context,
      builder: (_) => TicketFormSheet(orderId: orderId),
    );
  }

  @override
  ConsumerState<TicketFormSheet> createState() => _TicketFormSheetState();
}

class _TicketFormSheetState extends ConsumerState<TicketFormSheet> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _category = 'general';
  String _priority = 'normal';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final description = _description.text.trim();
    if (subject.length < 3) {
      setState(() => _error = 'Subject must be at least 3 characters.');
      return;
    }
    if (description.length < 10) {
      setState(() => _error = 'Description must be at least 10 characters.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref
        .read(ticketsProvider.notifier)
        .create(
          subject: subject,
          description: description,
          category: _category,
          priority: _priority,
          orderId: widget.orderId,
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
        Text('New support ticket', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(controller: _subject, labelText: 'Subject'),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in SupportTicketMeta.categories)
                    DropdownMenuItem(
                      value: c,
                      child: Text(SupportTicketMeta.label(c)),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final p in SupportTicketMeta.priorities)
                    DropdownMenuItem(
                      value: p,
                      child: Text(SupportTicketMeta.label(p)),
                    ),
                ],
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        MultilineTextField(
          controller: _description,
          labelText: 'How can we help?',
          minLines: 3,
          maxLines: 6,
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
            label: 'Submit',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
