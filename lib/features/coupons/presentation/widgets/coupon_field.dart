import 'package:flutter/material.dart';

import '../../../../shared/design_system.dart';

/// Coupon-code entry used on the checkout screen. It only captures the code via
/// [controller]; application happens after the order is created (the server is
/// authoritative for the discount). Single-coupon only — there is no removal
/// path because the backend exposes no un-redeem RPC.
class CouponField extends StatelessWidget {
  const CouponField({super.key, required this.controller, this.enabled = true});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      readOnly: !enabled,
      labelText: 'Coupon code (optional)',
      hintText: 'e.g. WELCOME10',
      prefixIcon: Icons.local_offer_outlined,
      textInputAction: TextInputAction.done,
    );
  }
}
