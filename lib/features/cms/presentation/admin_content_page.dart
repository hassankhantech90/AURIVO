import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/design_system.dart';
import '../domain/entities/cms_entities.dart';
import '../providers/cms_providers.dart';

/// Admin CMS (Requirements Doc §6): Home banners and FAQ / policy / info
/// pages. Writes are admin-only under RLS.
class AdminContentPage extends ConsumerWidget {
  const AdminContentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Content'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Banners'), Tab(text: 'Pages & FAQs')],
          ),
        ),
        body: const TabBarView(children: [_BannersTab(), _PagesTab()]),
      ),
    );
  }
}

Future<void> _report(
  BuildContext context,
  Future<void> Function() action,
  String done,
) async {
  try {
    await action();
    if (context.mounted) LuxurySnackBars.success(context, done);
  } catch (error) {
    if (context.mounted) LuxurySnackBars.error(context, error.toString());
  }
}

class _BannersTab extends ConsumerWidget {
  const _BannersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminBannersProvider);
    Future<void> edit([CmsBanner? banner]) async {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _BannerForm(initial: banner),
      );
      if (saved == true) {
        ref.invalidate(adminBannersProvider);
        ref.invalidate(homeBannersProvider);
      }
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: edit,
        icon: const Icon(Icons.add),
        label: const Text('New banner'),
      ),
      body: async.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load banners.',
          onRetry: () => ref.invalidate(adminBannersProvider),
        ),
        data: (banners) => banners.isEmpty
            ? const EmptyStateWidget(
                title: 'No banners',
                message: 'Home shows featured products until you add one.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  96,
                ),
                itemCount: banners.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final b = banners[i];
                  return LuxuryCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: b.imageUrl == null
                          ? const Icon(Icons.image_not_supported_outlined)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Image.network(
                                b.imageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                      title: Text(b.title),
                      subtitle: Text(
                        [
                          b.isActive ? 'Live' : 'Hidden',
                          if (b.link != null) b.link!,
                          'Order ${b.sortOrder}',
                        ].join(' · '),
                      ),
                      onTap: () => edit(b),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await LuxuryDialogs.showConfirmation(
                            context: context,
                            title: 'Delete banner?',
                            message: 'Remove "${b.title}" from Home.',
                            confirmLabel: 'Delete',
                            cancelLabel: 'Keep',
                          );
                          if (ok != true || !context.mounted) return;
                          await _report(
                            context,
                            () => ref.read(cmsRepositoryProvider).deleteBanner(b.id),
                            'Banner deleted.',
                          );
                          ref.invalidate(adminBannersProvider);
                          ref.invalidate(homeBannersProvider);
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _BannerForm extends ConsumerStatefulWidget {
  const _BannerForm({this.initial});

  final CmsBanner? initial;

  @override
  ConsumerState<_BannerForm> createState() => _BannerFormState();
}

class _BannerFormState extends ConsumerState<_BannerForm> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _subtitle = TextEditingController(text: widget.initial?.subtitle);
  late final _link = TextEditingController(text: widget.initial?.link ?? '/explore');
  late final _order = TextEditingController(
    text: '${widget.initial?.sortOrder ?? 0}',
  );
  late bool _active = widget.initial?.isActive ?? true;
  late String? _imagePath = widget.initial?.imagePath;
  Uint8List? _preview;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _subtitle, _link, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    try {
      final path = await ref.read(cmsRepositoryProvider).uploadBannerImage(bytes, ext);
      if (mounted) {
        setState(() {
          _imagePath = path;
          _preview = bytes;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final link = _link.text.trim();
    if (title.length < 2) {
      setState(() => _error = 'Add a headline.');
      return;
    }
    if (link.isNotEmpty && !link.startsWith('/')) {
      setState(() => _error = 'Links are in-app routes starting with "/".');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsRepositoryProvider).saveBanner({
        'title': title,
        'subtitle': _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
        'link': link.isEmpty ? null : link,
        'image_path': _imagePath,
        'sort_order': int.tryParse(_order.text.trim()) ?? 0,
        'is_active': _active,
      }, id: widget.initial?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'New banner' : 'Edit banner',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: InkWell(
                onTap: _pickImage,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.mistGrey,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: _preview != null
                      ? Image.memory(_preview!, fit: BoxFit.cover)
                      : widget.initial?.imageUrl != null && _imagePath == widget.initial?.imagePath
                      ? Image.network(widget.initial!.imageUrl!, fit: BoxFit.cover)
                      : const Center(child: Text('Tap to choose an image')),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(controller: _title, labelText: 'Headline'),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(controller: _subtitle, labelText: 'Subtitle (optional)'),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              controller: _link,
              labelText: 'Link (in-app route)',
              hintText: '/explore?material=Gold',
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              controller: _order,
              labelText: 'Display order',
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Live on Home'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.md),
            LoadingButton(label: 'Save', isLoading: _saving, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}

class _PagesTab extends ConsumerWidget {
  const _PagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPagesProvider);
    Future<void> edit([CmsPage? page]) async {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _PageForm(initial: page),
      );
      if (saved == true) {
        ref.invalidate(adminPagesProvider);
        for (final kind in CmsPage.kinds.keys) {
          ref.invalidate(cmsPagesProvider(kind));
        }
      }
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: edit,
        icon: const Icon(Icons.add),
        label: const Text('New page'),
      ),
      body: async.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load pages.',
          onRetry: () => ref.invalidate(adminPagesProvider),
        ),
        data: (pages) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            96,
          ),
          itemCount: pages.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) {
            final p = pages[i];
            return LuxuryCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(p.title),
                subtitle: Text(
                  '${CmsPage.kinds[p.kind] ?? p.kind} · /${p.slug}'
                  '${p.isPublished ? '' : ' · Hidden'}',
                ),
                onTap: () => edit(p),
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await LuxuryDialogs.showConfirmation(
                      context: context,
                      title: 'Delete page?',
                      message: 'Remove "${p.title}".',
                      confirmLabel: 'Delete',
                      cancelLabel: 'Keep',
                    );
                    if (ok != true || !context.mounted) return;
                    await _report(
                      context,
                      () => ref.read(cmsRepositoryProvider).deletePage(p.id),
                      'Page deleted.',
                    );
                    ref.invalidate(adminPagesProvider);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PageForm extends ConsumerStatefulWidget {
  const _PageForm({this.initial});

  final CmsPage? initial;

  @override
  ConsumerState<_PageForm> createState() => _PageFormState();
}

class _PageFormState extends ConsumerState<_PageForm> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _slug = TextEditingController(text: widget.initial?.slug);
  late final _body = TextEditingController(text: widget.initial?.body);
  late final _order = TextEditingController(
    text: '${widget.initial?.sortOrder ?? 0}',
  );
  late String _kind = widget.initial?.kind ?? CmsPage.faq;
  late bool _published = widget.initial?.isPublished ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _slug, _body, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _slugify(String v) => v
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _save() async {
    final title = _title.text.trim();
    final slug = _slugify(_slug.text.isEmpty ? title : _slug.text);
    if (title.length < 2 || slug.isEmpty) {
      setState(() => _error = 'A title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsRepositoryProvider).savePage({
        'title': title,
        'slug': slug,
        'kind': _kind,
        'body': _body.text.trim(),
        'sort_order': int.tryParse(_order.text.trim()) ?? 0,
        'is_published': _published,
      }, id: widget.initial?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'New page' : 'Edit page',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final e in CmsPage.kinds.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _kind == e.key,
                    onSelected: (_) => setState(() => _kind = e.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              controller: _title,
              labelText: _kind == CmsPage.faq ? 'Question' : 'Title',
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              controller: _slug,
              labelText: 'URL slug (optional — from title)',
            ),
            const SizedBox(height: AppSpacing.md),
            MultilineTextField(
              controller: _body,
              labelText: _kind == CmsPage.faq ? 'Answer' : 'Content',
              minLines: 5,
              maxLines: 14,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
              controller: _order,
              labelText: 'Display order',
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Published'),
              value: _published,
              onChanged: (v) => setState(() => _published = v),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.md),
            LoadingButton(label: 'Save', isLoading: _saving, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
