import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';
import 'luxury_card.dart';

/// Informational card for static messages and concise guidance.
class InformationCard extends StatelessWidget {
  const InformationCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Statistic card for dashboards and profile summary metrics.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, color: AppColors.primaryGold),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Editorial quote card for testimonials and brand storytelling surfaces.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.quote, this.author});

  final String quote;
  final String? author;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote, color: AppColors.primaryGold),
          const SizedBox(height: AppSpacing.sm),
          Text(quote, style: Theme.of(context).textTheme.titleLarge),
          if (author != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(author!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Order summary card for reusable order list and detail surfaces.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.orderNumber,
    required this.status,
    required this.total,
    this.currency = 'USD',
    this.dateLabel,
    this.onTap,
  });

  final String orderNumber;
  final String status;
  final num total;
  final String currency;
  final String? dateLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.primaryGold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderNumber,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (dateLabel != null)
                  Text(
                    dateLabel!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  status,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.deepGold),
                ),
              ],
            ),
          ),
          Text(
            '$currency ${total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
