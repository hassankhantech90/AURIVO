import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../admin/providers/admin_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../../push/providers/push_providers.dart';
import '../../seller/providers/seller_product_providers.dart';
import '../domain/entities/app_settings.dart';
import '../providers/settings_providers.dart';

/// App name/version shown in the About section. Kept as a constant to avoid an
/// extra platform plugin; update alongside `pubspec.yaml`.
const String _appName = 'AURIVO';
const String _appVersion = '1.0.0';

/// Buyer-facing settings: appearance (theme), account (email + sign out),
/// local preferences, and about. All state is device-local — no server calls
/// beyond sign-out.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Sign out?',
      message: 'You can sign back in anytime.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay',
    );
    if (confirmed != true || !context.mounted) return;
    // Unregister this device's push registration while the session is still
    // authenticated — unregister_push_device resolves the owner from
    // current_profile_id(), which is gone once signOut() clears the session.
    // Best-effort: sign-out must proceed even if this fails; no token is logged.
    try {
      await ref.read(pushRegistrarProvider).unregister();
    } catch (_) {
      // Ignore: the PushBootstrap auth->unauth listener remains as a fallback.
    }
    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(sessionProvider);

    final l10n = context.l10n;
    final locale = ref.watch(appLocaleProvider);

    return Scaffold(
      appBar: LuxuryAppBar(title: l10n.settingsTitle, showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          _SectionLabel(l10n.settingsLanguage),
          for (final (code, label) in [
            ('en', l10n.languageEnglish),
            ('ur', l10n.languageUrdu),
          ])
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(label),
              trailing: locale.languageCode == code
                  ? const Icon(Icons.check, color: AppColors.primaryGold)
                  : null,
              onTap: () =>
                  ref.read(appLocaleProvider.notifier).set(Locale(code)),
            ),

          const _SectionLabel('Appearance'),
          for (final mode in AppThemeMode.values)
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text(mode.label()),
              trailing: settings.themeMode == mode
                  ? const Icon(Icons.check, color: AppColors.primaryGold)
                  : null,
              onTap: () =>
                  ref.read(settingsProvider.notifier).setThemeMode(mode),
            ),

          const _SectionLabel('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(session.user?.email ?? 'Guest'),
            subtitle: Text(
              session.isAuthenticated ? 'Signed in' : 'Not signed in',
            ),
          ),
          if (session.isAuthenticated) ...[
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Profile & addresses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.profile),
            ),
            ListTile(
              leading: const Icon(Icons.business_center_outlined),
              title: const Text('Business account'),
              subtitle: const Text('Register for wholesale'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.businessAccount),
            ),
            // Seller Studio entry — shown only when the user has a seller store.
            if (ref.watch(mySellerProfileIdProvider).valueOrNull != null)
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Seller Studio'),
                subtitle: const Text('Manage your products'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.sellerDashboard),
              ),
            // Staff console — admins, support and finance staff.
            if (ref.watch(staffAccessProvider).valueOrNull?.isStaff ?? false)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(
                  ref.watch(staffAccessProvider).valueOrNull?.isAdmin ?? false
                      ? 'Admin console'
                      : 'Staff console',
                ),
                subtitle: const Text('Moderation, orders, support & finance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.admin),
              ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.helpCentre),
              subtitle: const Text('FAQs, returns, delivery & policies'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.help),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Help & support'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.support),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Sign out'),
              onTap: () => _signOut(context, ref),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in'),
              onTap: () => context.push(AppRoutes.login),
            ),

          const _SectionLabel('Preferences'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Order & promo notifications'),
            subtitle: const Text('Show alerts about orders and offers.'),
            value: settings.notificationsEnabled,
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setNotificationsEnabled(value),
          ),

          const _SectionLabel('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: Text('$_appName $_appVersion'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                LuxurySnackBars.info(context, 'Terms will be available soon.'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                LuxurySnackBars.info(context, 'Privacy policy coming soon.'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.primaryGold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
