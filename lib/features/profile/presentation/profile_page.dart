import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/supabase/supabase_storage_service.dart';
import '../../../shared/design_system.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/repositories/supabase_profile_repository.dart';
import '../domain/entities/profile.dart';
import '../providers/profile_providers.dart';
import 'widgets/edit_profile_sheet.dart';

/// The buyer's account screen: profile details, avatar, and links to address
/// management (and, in a later slice, seller onboarding).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _picker = ImagePicker();
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sessionProvider).isAuthenticated) _load();
    });
  }

  Future<void> _load() => ref.read(profileProvider.notifier).load();

  Future<void> _changePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _uploadingAvatar = true);
    await ref.read(profileProvider.notifier).uploadAvatar(bytes);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    final state = ref.read(profileProvider);
    if (state.status == ProfileViewStatus.failure) {
      LuxurySnackBars.error(
        context,
        state.message ?? 'Could not update photo.',
      );
    } else {
      LuxurySnackBars.success(context, 'Photo updated.');
    }
  }

  String? _avatarUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      return const SupabaseStorageService(
        supabaseService: SupabaseService(),
      ).getPublicUrl(
        bucket: SupabaseProfileRepository.avatarBucket,
        path: path,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(sessionProvider).isAuthenticated;
    if (!isAuthenticated) {
      return Scaffold(
        appBar: const LuxuryAppBar(title: 'Account'),
        body: EmptyStateWidget(
          title: 'Sign in to AURIVO',
          message: 'Manage your profile, addresses and orders.',
          icon: Icons.person_outline,
          action: PrimaryButton(
            label: 'Sign in',
            onPressed: () => context.push(AppRoutes.login),
          ),
        ),
      );
    }

    final state = ref.watch(profileProvider);
    final profile = state.data;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Account'),
      body: switch (state.status) {
        ProfileViewStatus.initial || ProfileViewStatus.loading
            when profile == null =>
          const Center(child: LoadingIndicator()),
        ProfileViewStatus.failure when profile == null => ErrorStateWidget(
          message: state.message ?? 'Could not load your profile.',
          onRetry: _load,
        ),
        _ =>
          profile == null
              ? const Center(child: LoadingIndicator())
              : _ProfileBody(
                  profile: profile,
                  avatarUrl: _avatarUrl(profile.avatarPath),
                  uploadingAvatar: _uploadingAvatar,
                  onChangePhoto: _changePhoto,
                  onEdit: () =>
                      EditProfileSheet.show(context, profile: profile),
                  onAddresses: () => context.push(AppRoutes.addresses),
                ),
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.avatarUrl,
    required this.uploadingAvatar,
    required this.onChangePhoto,
    required this.onEdit,
    required this.onAddresses,
  });

  final Profile profile;
  final String? avatarUrl;
  final bool uploadingAvatar;
  final VoidCallback onChangePhoto;
  final VoidCallback onEdit;
  final VoidCallback onAddresses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  LuxuryAvatar(
                    imageUrl: avatarUrl,
                    initials: profile.fullName.characters.firstOrNull,
                    size: 96,
                  ),
                  Material(
                    color: AppColors.primaryGold,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: uploadingAvatar ? null : onChangePhoto,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: uploadingAvatar
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.pureWhite,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: AppColors.pureWhite,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(profile.fullName, style: theme.textTheme.titleLarge),
              if (profile.email != null)
                Text(profile.email!, style: theme.textTheme.bodySmall),
              if (profile.phone != null)
                Text(profile.phone!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: LuxuryOutlinedButton(label: 'Edit profile', onPressed: onEdit),
        ),
        const SizedBox(height: AppSpacing.lg),
        LuxuryCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Addresses'),
            subtitle: const Text('Manage your shipping addresses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onAddresses,
          ),
        ),
      ],
    );
  }
}
