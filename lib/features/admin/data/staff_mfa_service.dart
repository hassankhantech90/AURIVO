import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

/// Where the signed-in staff member is in the MFA flow.
enum StaffMfaState {
  /// No authenticator set up yet — must enrol before using the console.
  needsEnrolment,

  /// Enrolled, but this session hasn't passed the second factor.
  needsCode,

  /// Session is at AAL2 (or MFA isn't applicable).
  satisfied,
}

/// A started TOTP enrolment: the key to type into an authenticator app, and
/// an `otpauth://` link that opens one directly.
class TotpSetup {
  const TotpSetup({
    required this.factorId,
    required this.secret,
    required this.uri,
  });

  final String factorId;
  final String secret;
  final String uri;
}

/// Thin wrapper over Supabase Auth MFA (TOTP) for staff accounts
/// (Requirements Doc §9 "MFA for admin roles"). The server only honours staff
/// roles on AAL2 sessions once a factor is verified (migration 48).
class StaffMfaService {
  const StaffMfaService(this._service);

  final SupabaseService _service;

  GoTrueMFAApi get _mfa => _service.client.auth.mfa;

  Future<StaffMfaState> state() async {
    final factors = await _mfa.listFactors();
    final verified = factors.totp.where(
      (f) => f.status == FactorStatus.verified,
    );
    if (verified.isEmpty) return StaffMfaState.needsEnrolment;
    final level = _mfa.getAuthenticatorAssuranceLevel().currentLevel;
    return level == AuthenticatorAssuranceLevels.aal2
        ? StaffMfaState.satisfied
        : StaffMfaState.needsCode;
  }

  Future<TotpSetup> startEnrolment() async {
    // Drop any half-finished enrolment so the user isn't left with stale keys.
    final existing = await _mfa.listFactors();
    for (final f in existing.totp.where(
      (f) => f.status != FactorStatus.verified,
    )) {
      await _mfa.unenroll(f.id);
    }
    final res = await _mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'Pareezay.Hub',
      friendlyName: 'Pareezay.Hub staff',
    );
    final totp = res.totp!;
    return TotpSetup(factorId: res.id, secret: totp.secret, uri: totp.uri);
  }

  /// Confirms enrolment (or a sign-in challenge) with a 6-digit code.
  Future<void> verify(String factorId, String code) =>
      _mfa.challengeAndVerify(factorId: factorId, code: code.trim());

  /// Verifies a code against the user's enrolled authenticator.
  Future<void> verifyExisting(String code) async {
    final factors = await _mfa.listFactors();
    final factor = factors.totp.firstWhere(
      (f) => f.status == FactorStatus.verified,
    );
    await verify(factor.id, code);
  }
}

final staffMfaServiceProvider = Provider<StaffMfaService>(
  (ref) => const StaffMfaService(SupabaseService()),
);

/// The current MFA state for staff (re-read after enrol / verify).
final staffMfaStateProvider = FutureProvider.autoDispose<StaffMfaState>(
  (ref) => ref.watch(staffMfaServiceProvider).state(),
);
