import 'package:flutter/material.dart';

import '../../../shared/design_system.dart';
import '../domain/entities/order_status.dart';

/// Colour-coded badge for an order status, reusing [LuxuryBadge].
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return LuxuryBadge(
      label: OrderStatus.label(status),
      backgroundColor: bg,
      foregroundColor: fg,
    );
  }

  (Color, Color) _colors(String status) {
    switch (status) {
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return (AppColors.success.withValues(alpha: 0.16), AppColors.success);
      case OrderStatus.cancelled:
      case OrderStatus.returned:
      case OrderStatus.refunded:
        return (AppColors.error.withValues(alpha: 0.14), AppColors.error);
      case OrderStatus.shipped:
      case OrderStatus.packed:
      case OrderStatus.processing:
      case OrderStatus.confirmed:
        return (
          AppColors.primaryGold.withValues(alpha: 0.18),
          AppColors.deepGold,
        );
      default:
        return (AppColors.porcelain, AppColors.charcoal);
    }
  }
}
