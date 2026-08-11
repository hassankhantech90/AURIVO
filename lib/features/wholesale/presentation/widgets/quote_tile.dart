import 'package:flutter/material.dart';

import '../../../../shared/design_system.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/rfq_status.dart';

/// Read-only display of a seller's quote against an RFQ. The buyer app never
/// mutates quotes and the schema has no "accepted quote" linkage, so this is
/// purely informational (no accept/reject actions).
class QuoteTile extends StatelessWidget {
  const QuoteTile({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${quote.currency} ${quote.unitPrice.toStringAsFixed(2)} / unit',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              LuxuryBadge(
                label: QuoteStatus.label(quote.status),
                backgroundColor: AppColors.porcelain,
                foregroundColor: AppColors.charcoal,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Total ${quote.currency} ${quote.totalPrice.toStringAsFixed(2)} · '
            'MOQ ${quote.minimumOrderQuantity}'
            '${quote.leadTimeDays != null ? ' · ${quote.leadTimeDays} day lead' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          if (quote.message != null && quote.message!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(quote.message!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
