import 'package:flutter/material.dart';

import '../../../../shared/design_system.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/rfq_status.dart';

/// Display of a seller's quote against an RFQ. When [onAccept] is provided the
/// buyer can accept it, which converts the quote into an order; otherwise the
/// tile is informational.
class QuoteTile extends StatelessWidget {
  const QuoteTile({super.key, required this.quote, this.onAccept, this.busy = false});

  final Quote quote;

  /// Called when the buyer accepts this quote. Null when the quote cannot be
  /// accepted (wrong status, expired, RFQ closed, or not linked to a product).
  final VoidCallback? onAccept;

  /// Whether an accept is in flight (disables the button + shows a spinner).
  final bool busy;

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
          if (onAccept != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Accept & order',
                icon: Icons.check_circle_outline,
                isLoading: busy,
                onPressed: busy ? null : onAccept,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
