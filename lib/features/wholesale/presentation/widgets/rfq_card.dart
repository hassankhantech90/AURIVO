import 'package:flutter/material.dart';

import '../../../../shared/design_system.dart';
import '../../domain/entities/rfq.dart';
import '../../domain/entities/rfq_status.dart';

/// List card summarising one of the buyer's RFQs.
class RfqCard extends StatelessWidget {
  const RfqCard({super.key, required this.rfq, this.onTap});

  final Rfq rfq;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Qty ${rfq.quantity}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    LuxuryBadge(
                      label: RfqStatus.label(rfq.status),
                      backgroundColor: AppColors.porcelain,
                      foregroundColor: AppColors.charcoal,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  rfq.targetPrice != null
                      ? 'Target ${rfq.currency} ${rfq.targetPrice!.toStringAsFixed(2)} / unit'
                      : 'No target price',
                  style: theme.textTheme.bodySmall,
                ),
                if (rfq.message != null && rfq.message!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    rfq.message!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.softGrey),
        ],
      ),
    );
  }
}
