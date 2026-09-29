import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../profile/providers/profile_providers.dart';

/// Gate for wholesale actions (creating an RFQ): returns true only when the
/// current buyer is a verified business. Otherwise it shows an explanatory
/// message, routes to the business account, and returns false. The server
/// (`enforce_rfq_verified_business`) is the authoritative gate; this keeps the
/// buyer from filling a form only to be rejected.
Future<bool> ensureVerifiedBusiness(BuildContext context, WidgetRef ref) async {
  final business = await ref
      .read(profileRepositoryProvider)
      .getBusinessProfile();
  if (business?.verificationStatus == 'verified') return true;
  if (!context.mounted) return false;

  final message = switch (business?.verificationStatus) {
    'pending' => 'Your business is still under review for wholesale access.',
    'rejected' =>
      'Your business verification was declined — see your business account.',
    'suspended' => 'Your business account is suspended. Contact support.',
    _ => 'Register your business to request wholesale quotes.',
  };
  LuxurySnackBars.info(context, message);
  context.push(AppRoutes.businessAccount);
  return false;
}
