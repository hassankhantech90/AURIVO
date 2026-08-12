import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/design_system.dart';
import '../domain/entities/seller_image.dart';
import '../providers/seller_image_providers.dart';
import '../providers/seller_providers.dart' show SellerViewStatus;

/// Image manager for a single seller product: pick & upload from the device,
/// display, set primary, reorder (drag), and delete (storage object + row).
class SellerImagesPage extends ConsumerStatefulWidget {
  const SellerImagesPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<SellerImagesPage> createState() => _SellerImagesPageState();
}

class _SellerImagesPageState extends ConsumerState<SellerImagesPage> {
  final _picker = ImagePicker();
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(productImagesProvider(widget.productId).notifier).load();

  Future<void> _pickAndUpload() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';

    setState(() => _uploading = true);
    final error = await ref
        .read(productImagesProvider(widget.productId).notifier)
        .upload(bytes: bytes, fileExtension: ext, contentType: file.mimeType);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      LuxurySnackBars.success(context, 'Image uploaded.');
    }
  }

  Future<void> _setPrimary(SellerImage image) async {
    final error = await ref
        .read(productImagesProvider(widget.productId).notifier)
        .setPrimary(image.id);
    if (!mounted) return;
    if (error != null) LuxurySnackBars.error(context, error);
  }

  Future<void> _delete(SellerImage image) async {
    final confirmed = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Delete image?',
      message: 'This permanently removes the image.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
    );
    if (confirmed != true || !mounted) return;
    final error = await ref
        .read(productImagesProvider(widget.productId).notifier)
        .remove(image);
    if (!mounted) return;
    if (error != null) LuxurySnackBars.error(context, error);
  }

  Future<void> _onReorder(List<SellerImage> images, int oldI, int newI) async {
    final reordered = [...images];
    var target = newI;
    if (target > oldI) target -= 1;
    final moved = reordered.removeAt(oldI);
    reordered.insert(target, moved);
    final error = await ref
        .read(productImagesProvider(widget.productId).notifier)
        .reorder(reordered.map((i) => i.id).toList());
    if (!mounted) return;
    if (error != null) LuxurySnackBars.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productImagesProvider(widget.productId));
    final images = state.data ?? const [];

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Images', showBackButton: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _pickAndUpload,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add image'),
      ),
      body: switch (state.status) {
        SellerViewStatus.initial || SellerViewStatus.loading
            when state.data == null =>
          const Center(child: LoadingIndicator()),
        SellerViewStatus.failure when state.data == null => ErrorStateWidget(
          message: state.message ?? 'Could not load images.',
          onRetry: _load,
        ),
        _ =>
          images.isEmpty
              ? const EmptyStateWidget(
                  title: 'No images yet',
                  message: 'Add photos so buyers can see this piece.',
                  icon: Icons.photo_library_outlined,
                )
              : ReorderableListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  onReorder: (oldI, newI) => _onReorder(images, oldI, newI),
                  children: [
                    for (final image in images)
                      _ImageRow(
                        key: ValueKey(image.id),
                        image: image,
                        onSetPrimary: () => _setPrimary(image),
                        onDelete: () => _delete(image),
                      ),
                  ],
                ),
      },
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({
    super.key,
    required this.image,
    required this.onSetPrimary,
    required this.onDelete,
  });

  final SellerImage image;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: LuxuryCard(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 64,
                height: 64,
                child: NetworkImageWidget(imageUrl: image.publicUrl),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: image.isPrimary
                  ? const LuxuryBadge(
                      label: 'Primary',
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: AppColors.pureWhite,
                    )
                  : TextButton(
                      onPressed: onSetPrimary,
                      child: const Text('Set as primary'),
                    ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
