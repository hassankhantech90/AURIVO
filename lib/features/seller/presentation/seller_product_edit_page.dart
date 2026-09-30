import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/product_draft.dart';
import '../providers/seller_product_providers.dart';

/// Create/edit form for a seller product. `productId == null` → create mode.
/// The buyer/ownership fields are never entered here: `seller_id` is server-set
/// and publish status is managed separately on the dashboard.
class SellerProductEditPage extends ConsumerStatefulWidget {
  const SellerProductEditPage({super.key, this.productId});

  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<SellerProductEditPage> createState() =>
      _SellerProductEditPageState();
}

class _SellerProductEditPageState extends ConsumerState<SellerProductEditPage> {
  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _jewelleryType = TextEditingController();
  final _basePrice = TextEditingController();
  final _comparePrice = TextEditingController();
  final _description = TextEditingController();
  final _minOrderQuantity = TextEditingController();
  final _purity = TextEditingController();
  final _certification = TextEditingController();
  final _makingCharges = TextEditingController();
  final _dimensions = TextEditingController();
  final _leadTimeDays = TextEditingController();
  final _advancePercent = TextEditingController();

  String _currency = 'PKR';
  String? _gender;
  String? _brandId;
  String? _material;
  bool _returnable = true;
  bool _madeToOrder = false;

  static const _materials = ['Gold', 'Silver', 'Artificial'];
  final Set<String> _categoryIds = {};

  bool _loading = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _slug,
      _jewelleryType,
      _basePrice,
      _comparePrice,
      _description,
      _minOrderQuantity,
      _purity,
      _certification,
      _makingCharges,
      _dimensions,
      _leadTimeDays,
      _advancePercent,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prefill() async {
    try {
      final detail = await ref
          .read(sellerProductRepositoryProvider)
          .getProduct(widget.productId!);
      final p = detail.product;
      _title.text = p.title;
      _slug.text = p.slug;
      _jewelleryType.text = p.jewelleryType;
      _basePrice.text = p.basePrice.toString();
      _comparePrice.text = p.comparePrice?.toString() ?? '';
      _description.text = p.description ?? '';
      _minOrderQuantity.text = p.minOrderQuantity?.toString() ?? '';
      _currency = p.currency;
      _gender = p.gender;
      _brandId = p.brandId;
      _material = p.material;
      _purity.text = p.purity ?? '';
      _certification.text = p.certification ?? '';
      _makingCharges.text = p.makingCharges?.toString() ?? '';
      _dimensions.text = p.dimensions ?? '';
      _returnable = p.isReturnable;
      _madeToOrder = p.isMadeToOrder;
      _leadTimeDays.text = p.leadTimeDays?.toString() ?? '';
      _advancePercent.text = p.advancePaymentPercent?.toString() ?? '';
      _categoryIds
        ..clear()
        ..addAll(detail.categoryIds);
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _slugify(String value) {
    final s = value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s;
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final jewelleryType = _jewelleryType.text.trim();
    final basePrice = double.tryParse(_basePrice.text.trim());
    final slug = _slug.text.trim().isEmpty
        ? _slugify(title)
        : _slugify(_slug.text);

    if (title.isEmpty || jewelleryType.isEmpty || basePrice == null) {
      setState(
        () => _error =
            'Title, jewellery type and a valid base price are '
            'required.',
      );
      return;
    }
    if (slug.isEmpty) {
      setState(() => _error = 'Please provide a valid product URL (slug).');
      return;
    }
    final makingCharges = _makingCharges.text.trim().isEmpty
        ? null
        : double.tryParse(_makingCharges.text.trim());
    if (_makingCharges.text.trim().isNotEmpty &&
        (makingCharges == null || makingCharges < 0)) {
      setState(() => _error = 'Making charges must be a positive amount.');
      return;
    }
    final leadTimeDays = int.tryParse(_leadTimeDays.text.trim());
    final advancePercent = int.tryParse(_advancePercent.text.trim());
    if (_madeToOrder && (leadTimeDays == null || leadTimeDays <= 0)) {
      setState(
        () => _error = 'Made-to-order items need a lead time in days.',
      );
      return;
    }
    if (advancePercent != null && (advancePercent < 0 || advancePercent > 100)) {
      setState(() => _error = 'Advance payment must be between 0 and 100%.');
      return;
    }

    final draft = ProductDraft(
      title: title,
      slug: slug,
      jewelleryType: jewelleryType,
      basePrice: basePrice,
      currency: _currency,
      comparePrice: double.tryParse(_comparePrice.text.trim()),
      description: _description.text,
      gender: _gender,
      brandId: _brandId,
      minOrderQuantity: int.tryParse(_minOrderQuantity.text.trim()),
      categoryIds: _categoryIds.toList(),
      material: _material,
      purity: _purity.text,
      certification: _certification.text,
      makingCharges: makingCharges,
      dimensions: _dimensions.text,
      isReturnable: _returnable,
      isMadeToOrder: _madeToOrder,
      // Lead time / advance only mean something for made-to-order items.
      leadTimeDays: _madeToOrder ? leadTimeDays : null,
      advancePaymentPercent: _madeToOrder ? advancePercent : null,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });

    final notifier = ref.read(myProductsProvider.notifier);
    final error = widget.isEditing
        ? await notifier.update(widget.productId!, draft)
        : await notifier.create(draft);

    if (!mounted) return;
    if (error == null) {
      LuxurySnackBars.success(
        context,
        widget.isEditing ? 'Product updated.' : 'Product created.',
      );
      context.pop();
    } else {
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  /// Metal, purity and the buyer disclosures the marketplace requires for
  /// precious-metal and made-to-order items (Requirements Doc §3).
  List<Widget> _complianceFields(BuildContext context) {
    final materials = [
      ..._materials,
      if (_material != null && !_materials.contains(_material)) _material!,
    ];
    return [
      Text('Details & compliance', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      DropdownButtonFormField<String?>(
        initialValue: _material,
        decoration: const InputDecoration(labelText: 'Metal'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Not set')),
          for (final m in materials) DropdownMenuItem(value: m, child: Text(m)),
        ],
        onChanged: (v) => setState(() => _material = v),
      ),
      const SizedBox(height: AppSpacing.md),
      CustomTextField(
        controller: _purity,
        labelText: 'Purity / karat (optional)',
        hintText: 'e.g. 22k, 925',
      ),
      const SizedBox(height: AppSpacing.md),
      CustomTextField(
        controller: _certification,
        labelText: 'Certification (optional)',
        hintText: 'e.g. PSQCA hallmark, GIA report no.',
      ),
      const SizedBox(height: AppSpacing.md),
      CustomTextField(
        controller: _makingCharges,
        labelText: 'Making charges (optional)',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: AppSpacing.md),
      CustomTextField(
        controller: _dimensions,
        labelText: 'Dimensions (optional)',
        hintText: 'e.g. 18 mm × 12 mm, chain 45 cm',
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Returnable'),
        subtitle: const Text('Buyers may return it under the AURIVO policy'),
        value: _returnable,
        onChanged: (v) => setState(() => _returnable = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Made to order'),
        subtitle: const Text('Crafted after purchase, with a lead time'),
        value: _madeToOrder,
        onChanged: (v) => setState(() => _madeToOrder = v),
      ),
      if (_madeToOrder) ...[
        const SizedBox(height: AppSpacing.sm),
        CustomTextField(
          controller: _leadTimeDays,
          labelText: 'Lead time (days)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _advancePercent,
          labelText: 'Advance payment % (optional)',
          keyboardType: TextInputType.number,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(sellerBrandsProvider);
    final categories = ref.watch(sellerCategoriesProvider);

    return Scaffold(
      appBar: LuxuryAppBar(
        title: widget.isEditing ? 'Edit product' : 'New product',
        showBackButton: true,
      ),
      body: _loading
          ? const Center(child: LoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                CustomTextField(
                  controller: _title,
                  labelText: 'Title',
                  hintText: 'e.g. Emerald Solitaire Ring',
                ),
                const SizedBox(height: AppSpacing.md),
                CustomTextField(
                  controller: _slug,
                  labelText: 'Product URL (optional — auto from title)',
                  hintText: 'emerald-solitaire-ring',
                ),
                const SizedBox(height: AppSpacing.md),
                CustomTextField(
                  controller: _jewelleryType,
                  labelText: 'Jewellery type',
                  hintText: 'ring, necklace, bracelet…',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    // Flexible shares (2:1) instead of a fixed-width currency
                    // box, so neither field overflows at large text scales.
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        controller: _basePrice,
                        labelText: 'Base price',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'PKR', child: Text('PKR')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (v) =>
                            setState(() => _currency = v ?? 'PKR'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                CustomTextField(
                  controller: _comparePrice,
                  labelText: 'Compare-at price (optional)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String?>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender (optional)',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any')),
                    DropdownMenuItem(value: 'women', child: Text('Women')),
                    DropdownMenuItem(value: 'men', child: Text('Men')),
                    DropdownMenuItem(value: 'unisex', child: Text('Unisex')),
                    DropdownMenuItem(value: 'kids', child: Text('Kids')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: AppSpacing.md),
                brands.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (list) => DropdownButtonFormField<String?>(
                    initialValue: _brandId,
                    decoration: const InputDecoration(
                      labelText: 'Brand (optional)',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      for (final b in list)
                        DropdownMenuItem(value: b.id, child: Text(b.name)),
                    ],
                    onChanged: (v) => setState(() => _brandId = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CustomTextField(
                  controller: _minOrderQuantity,
                  labelText: 'Minimum order quantity (optional)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                MultilineTextField(
                  controller: _description,
                  labelText: 'Description (optional)',
                  minLines: 3,
                  maxLines: 8,
                ),
                const SizedBox(height: AppSpacing.lg),
                ..._complianceFields(context),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Categories',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                categories.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Could not load categories.'),
                  data: (list) => Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final c in list)
                        FilterChip(
                          label: Text(c.name),
                          selected: _categoryIds.contains(c.id),
                          onSelected: (sel) => setState(() {
                            if (sel) {
                              _categoryIds.add(c.id);
                            } else {
                              _categoryIds.remove(c.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                LoadingButton(
                  label: widget.isEditing ? 'Save changes' : 'Create product',
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                if (widget.isEditing) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: LuxuryOutlinedButton(
                      label: 'Manage variants',
                      onPressed: () => context.push(
                        AppRoutes.sellerProductVariantsPath(widget.productId!),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: LuxuryOutlinedButton(
                      label: 'Manage images',
                      onPressed: () => context.push(
                        AppRoutes.sellerProductImagesPath(widget.productId!),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: LuxuryOutlinedButton(
                      label: 'Manage wholesale pricing',
                      onPressed: () => context.push(
                        AppRoutes.sellerProductTiersPath(widget.productId!),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  'New products start as Draft. Publish them from Seller Studio.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
