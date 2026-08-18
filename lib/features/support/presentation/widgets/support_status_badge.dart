import 'package:flutter/material.dart';

import '../../../../shared/design_system.dart';
import '../../domain/entities/support_ticket.dart';

/// A coloured badge for a support ticket status.
class SupportStatusBadge extends StatelessWidget {
  const SupportStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'open' => AppColors.primaryGold,
      'pending' => AppColors.warning,
      'resolved' => AppColors.success,
      'closed' => AppColors.softGrey,
      _ => AppColors.mediumGrey,
    };
    return LuxuryBadge(
      label: SupportTicketMeta.label(status),
      backgroundColor: color,
      foregroundColor: status == 'closed'
          ? AppColors.charcoal
          : AppColors.pureWhite,
    );
  }
}
