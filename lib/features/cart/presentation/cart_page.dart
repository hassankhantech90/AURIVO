import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../domain/entities/cart_item.dart';
import '../domain/entities/cart_view.dart';
import '../providers/cart_providers.dart';

/// Shopping cart screen wired to [cartProvider] (works for both authenticated
/// and guest carts — the repository resolves which behind the scenes).
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(cartProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cartProvider);
    final cart = state.cart;

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Cart',
        actions: [
          if (cart != null && !cart.isEmpty)
            IconButton(
              tooltip: 'Clear cart',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => ref.read(cartProvider.notifier).clear(),
            ),
        ],
      ),
      body: switch (state.status) {
        CartStatus.initial || CartStatus.loading when cart == null =>
          const Center(child: LoadingIndicator()),
        CartStatus.failure when cart == null => ErrorStateWidget(
          message: state.message ?? 'Could not load your cart.',
          onRetry: _load,
        ),
        _ =>
          cart == null || cart.isEmpty
              ? const EmptyStateWidget(
                  title: 'Your cart is empty',
                  message: 'Browse the catalogue and add something you love.',
                  icon: Icons.shopping_bag_outlined,
                )
              : _CartContent(cart: cart),
      },
    );
  }
}

class _CartContent extends ConsumerWidget {
  const _CartContent({required this.cart});

  final CartView cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: cart.items.length,
            separatorBuilder: (_, _) => const LuxuryDivider(),
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return _CartItemTile(item: item);
            },
          ),
        ),
        _CartSummary(cart: cart),
      ],
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Item', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              PriceWidget(price: item.lineTotal, currency: item.currency),
            ],
          ),
        ),
        QuantitySelector(
          value: item.quantity,
          onDecrement: () =>
              notifier.updateQuantity(item.productVariantId, item.quantity - 1),
          onIncrement: () =>
              notifier.updateQuantity(item.productVariantId, item.quantity + 1),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Remove',
          onPressed: () => notifier.removeItem(item.productVariantId),
        ),
      ],
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.cart});

  final CartView cart;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppColors.pureWhite,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cart.itemCount} item(s)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  PriceWidget(
                    price: cart.cart.grandTotal,
                    currency: cart.cart.currency,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Proceed to checkout',
                  // The checkout route redirects guests to login; authenticated
                  // buyers land on the checkout screen.
                  onPressed: () => context.push(AppRoutes.checkout),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
