import 'package:flutter/material.dart';

import '../../../../shared/design_system.dart';
import '../../../products/domain/entities/catalog_filters.dart';
import '../../../products/domain/entities/product_sort.dart';

/// The user's Explore refinements: ordering, metal, and price/purity filters.
class ExploreRefinement {
  const ExploreRefinement({
    this.sort = ProductSort.newest,
    this.material,
    this.filters = const CatalogFilters(),
  });

  final ProductSort sort;
  final String? material;
  final CatalogFilters filters;

  /// Number of active refinements, shown as a badge on the Filters button.
  int get activeCount =>
      (sort != ProductSort.newest ? 1 : 0) +
      (material != null ? 1 : 0) +
      (filters.minPrice != null || filters.maxPrice != null ? 1 : 0) +
      (filters.purity != null ? 1 : 0);
}

/// A price band shown as a single chip.
class PriceBand {
  const PriceBand(this.label, this.min, this.max);

  final String label;
  final double? min;
  final double? max;

  bool matches(CatalogFilters f) => f.minPrice == min && f.maxPrice == max;
}

/// Bottom sheet for sorting and filtering Explore (Requirements Doc §4.1:
/// material, price range, purity/karat). Returns the new refinement, or null
/// when dismissed.
class ExploreFilterSheet extends StatefulWidget {
  const ExploreFilterSheet({super.key, required this.initial});

  final ExploreRefinement initial;

  static const materials = ['Gold', 'Silver', 'Artificial'];
  static const purities = ['24k', '22k', '21k', '18k', '925'];
  static const priceBands = [
    PriceBand('Under 25k', null, 25000),
    PriceBand('25k – 100k', 25000, 100000),
    PriceBand('100k – 250k', 100000, 250000),
    PriceBand('250k +', 250000, null),
  ];
  static const sorts = {
    ProductSort.newest: 'Newest',
    ProductSort.priceLowToHigh: 'Price: low to high',
    ProductSort.priceHighToLow: 'Price: high to low',
    ProductSort.featured: 'Featured',
  };

  static Future<ExploreRefinement?> show(
    BuildContext context,
    ExploreRefinement initial,
  ) {
    return showModalBottomSheet<ExploreRefinement>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExploreFilterSheet(initial: initial),
    );
  }

  @override
  State<ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<ExploreFilterSheet> {
  late ProductSort _sort = widget.initial.sort;
  late String? _material = widget.initial.material;
  late CatalogFilters _filters = widget.initial.filters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort & filter', style: theme.textTheme.titleLarge),
            heading('Sort by'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in ExploreFilterSheet.sorts.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _sort == entry.key,
                    onSelected: (_) => setState(() => _sort = entry.key),
                  ),
              ],
            ),
            heading('Metal'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in ExploreFilterSheet.materials)
                  FilterChip(
                    label: Text(m),
                    selected: _material == m,
                    onSelected: (on) => setState(() => _material = on ? m : null),
                  ),
              ],
            ),
            heading('Purity / karat'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final p in ExploreFilterSheet.purities)
                  FilterChip(
                    label: Text(p),
                    selected: _filters.purity == p,
                    onSelected: (on) => setState(
                      () => _filters = on
                          ? _filters.copyWith(purity: p)
                          : _filters.copyWith(clearPurity: true),
                    ),
                  ),
              ],
            ),
            heading('Price (PKR)'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final band in ExploreFilterSheet.priceBands)
                  FilterChip(
                    label: Text(band.label),
                    selected: band.matches(_filters) &&
                        (_filters.minPrice != null || _filters.maxPrice != null),
                    onSelected: (on) => setState(
                      () => _filters = on
                          ? CatalogFilters(
                              minPrice: band.min,
                              maxPrice: band.max,
                              purity: _filters.purity,
                            )
                          : _filters.copyWith(clearPrice: true),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: LuxuryOutlinedButton(
                    label: 'Reset',
                    onPressed: () =>
                        Navigator.of(context).pop(const ExploreRefinement()),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    label: 'Apply',
                    onPressed: () => Navigator.of(context).pop(
                      ExploreRefinement(
                        sort: _sort,
                        material: _material,
                        filters: _filters,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
