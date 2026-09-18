import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/design_system.dart';
import '../../cart/providers/cart_providers.dart';
import '../../coupons/presentation/widgets/coupon_field.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../orders/domain/entities/order_status.dart';
import '../../profile/domain/entities/address.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/checkout_providers.dart';

/// Checkout screen. Collects a shipping address and (COD-only) payment method,
/// then places the order exclusively through the `checkout_cart` RPC via
/// [checkoutProvider]. The client never computes or sends any monetary value —
/// the cart total shown here is the database-authoritative cart row, for
/// display only.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  String? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Guest users cannot check out — the RPC rejects them and decision #2
      // requires a hard redirect to login. The router also guards this route.
      if (!ref.read(checkoutProvider.notifier).isAuthenticated) {
        context.go(AppRoutes.login);
        return;
      }
      ref.read(couponProvider.notifier).reset();
      ref.read(cartProvider.notifier).load();
      ref.read(addressesProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  String? _effectiveAddressId(List<Address> addresses) {
    if (addresses.isEmpty) return null;
    if (_selectedAddressId != null &&
        addresses.any((a) => a.id == _selectedAddressId)) {
      return _selectedAddressId;
    }
    final defaultAddress = addresses.where((a) => a.isDefault);
    return defaultAddress.isNotEmpty
        ? defaultAddress.first.id
        : addresses.first.id;
  }

  Future<void> _placeOrder(String cartId, String addressId) async {
    final orderId = await ref
        .read(checkoutProvider.notifier)
        .placeOrder(
          cartId: cartId,
          addressId: addressId,
          notes: _notesController.text,
        );
    if (!mounted) return;
    if (orderId == null) {
      final message =
          ref.read(checkoutProvider).message ??
          'Could not place your order. Please try again.';
      LuxurySnackBars.error(context, message);
      return;
    }

    // Cart is now converted server-side; refresh the local view.
    await ref.read(cartProvider.notifier).load();
    if (!mounted) return;

    // Optional coupon: applied AFTER the order exists, via the redeem_coupon
    // RPC (server computes the discount and updates the order totals). A failed
    // coupon must never undo the already-placed order — surface a warning and
    // continue to the order, which shows the authoritative totals.
    final code = _couponController.text.trim();
    if (code.isNotEmpty) {
      final couponError = await ref
          .read(couponProvider.notifier)
          .apply(code: code, orderId: orderId);
      if (!mounted) return;
      if (couponError != null) {
        LuxurySnackBars.warning(context, 'Order placed. $couponError');
      } else {
        LuxurySnackBars.success(context, 'Order placed and coupon applied.');
      }
    } else {
      LuxurySnackBars.success(context, 'Order placed successfully.');
    }

    if (!mounted) return;
    context.pushReplacement(AppRoutes.orderDetailPath(orderId));
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final addressState = ref.watch(addressesProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final cart = cartState.cart;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Checkout'),
      body: switch (cartState.status) {
        CartStatus.initial || CartStatus.loading when cart == null =>
          const Center(child: LoadingIndicator()),
        CartStatus.failure when cart == null => ErrorStateWidget(
          message: cartState.message ?? 'Could not load your cart.',
          onRetry: () => ref.read(cartProvider.notifier).load(),
        ),
        _ =>
          cart == null || cart.isEmpty
              ? EmptyStateWidget(
                  title: 'Your cart is empty',
                  message: 'Add something you love before checking out.',
                  icon: Icons.shopping_bag_outlined,
                  action: PrimaryButton(
                    label: 'Browse catalogue',
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                )
              : _CheckoutBody(
                  addresses: addressState.data ?? const [],
                  addressesLoading: addressState.isLoading,
                  addressesError:
                      addressState.status == ProfileViewStatus.failure
                      ? addressState.message
                      : null,
                  selectedAddressId: _effectiveAddressId(
                    addressState.data ?? const [],
                  ),
                  onSelectAddress: (id) =>
                      setState(() => _selectedAddressId = id),
                  onReloadAddresses: () =>
                      ref.read(addressesProvider.notifier).load(),
                  notesController: _notesController,
                  couponController: _couponController,
                  itemCount: cart.itemCount,
                  total: cart.cart.grandTotal,
                  currency: cart.cart.currency,
                  isSubmitting: checkoutState.isSubmitting,
                  onPlaceOrder: () {
                    final addressId = _effectiveAddressId(
                      addressState.data ?? const [],
                    );
                    if (addressId == null) {
                      LuxurySnackBars.warning(
                        context,
                        'Please add a shipping address first.',
                      );
                      return;
                    }
                    _placeOrder(cart.cart.id, addressId);
                  },
                ),
      },
    );
  }
}

class _CheckoutBody extends StatelessWidget {
  const _CheckoutBody({
    required this.addresses,
    required this.addressesLoading,
    required this.addressesError,
    required this.selectedAddressId,
    required this.onSelectAddress,
    required this.onReloadAddresses,
    required this.notesController,
    required this.couponController,
    required this.itemCount,
    required this.total,
    required this.currency,
    required this.isSubmitting,
    required this.onPlaceOrder,
  });

  final List<Address> addresses;
  final bool addressesLoading;
  final String? addressesError;
  final String? selectedAddressId;
  final ValueChanged<String> onSelectAddress;
  final VoidCallback onReloadAddresses;
  final TextEditingController notesController;
  final TextEditingController couponController;
  final int itemCount;
  final double total;
  final String currency;
  final bool isSubmitting;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    final hasAddress = selectedAddressId != null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Shipping address',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _AddressSection(
                addresses: addresses,
                loading: addressesLoading,
                error: addressesError,
                selectedAddressId: selectedAddressId,
                onSelect: onSelectAddress,
                onReload: onReloadAddresses,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Payment method',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              const _CashOnDeliveryTile(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Order note (optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              MultilineTextField(
                controller: notesController,
                hintText: 'Delivery instructions, landmarks, etc.',
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Coupon', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              CouponField(controller: couponController, enabled: !isSubmitting),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Applied after your order is placed; the final total updates '
                'on the order screen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _CheckoutSummaryBar(
          itemCount: itemCount,
          total: total,
          currency: currency,
          canPlaceOrder: hasAddress && !isSubmitting,
          isSubmitting: isSubmitting,
          onPlaceOrder: onPlaceOrder,
        ),
      ],
    );
  }
}

class _AddressSection extends StatelessWidget {
  const _AddressSection({
    required this.addresses,
    required this.loading,
    required this.error,
    required this.selectedAddressId,
    required this.onSelect,
    required this.onReload,
  });

  final List<Address> addresses;
  final bool loading;
  final String? error;
  final String? selectedAddressId;
  final ValueChanged<String> onSelect;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    if (loading && addresses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: LoadingIndicator()),
      );
    }
    if (error != null && addresses.isEmpty) {
      return _AddressNotice(
        message: error!,
        actionLabel: 'Retry',
        onAction: onReload,
      );
    }
    if (addresses.isEmpty) {
      return _AddressNotice(
        message: 'You have no saved addresses yet.',
        actionLabel: 'Add an address',
        onAction: () => context.push(AppRoutes.addresses),
      );
    }
    return Column(
      children: [
        for (final address in addresses)
          _AddressTile(
            address: address,
            selected: address.id == selectedAddressId,
            onTap: () => onSelect(address.id),
          ),
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      address.addressLine1,
      if (address.addressLine2 != null && address.addressLine2!.isNotEmpty)
        address.addressLine2!,
      if (address.area != null && address.area!.isNotEmpty) address.area!,
      '${address.city}, ${address.province}',
      if (address.postalCode != null && address.postalCode!.isNotEmpty)
        address.postalCode!,
      address.country,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? AppColors.primaryGold : AppColors.softGrey,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primaryGold : AppColors.softGrey,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.recipientName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (address.isDefault)
                          const LuxuryBadge(label: 'Default'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      address.phone,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      lines.join(', '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressNotice extends StatelessWidget {
  const _AddressNotice({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            LuxuryOutlinedButton(label: actionLabel, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}

class _CashOnDeliveryTile extends StatelessWidget {
  const _CashOnDeliveryTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.primaryGold, width: 1.4),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.payments_outlined,
          color: AppColors.primaryGold,
        ),
        title: Text(PaymentMethod.label(PaymentMethod.cashOnDelivery)),
        subtitle: const Text('Pay when your order arrives.'),
        trailing: const Icon(Icons.check_circle, color: AppColors.primaryGold),
      ),
    );
  }
}

class _CheckoutSummaryBar extends StatelessWidget {
  const _CheckoutSummaryBar({
    required this.itemCount,
    required this.total,
    required this.currency,
    required this.canPlaceOrder,
    required this.isSubmitting,
    required this.onPlaceOrder,
  });

  final int itemCount;
  final double total;
  final String currency;
  final bool canPlaceOrder;
  final bool isSubmitting;
  final VoidCallback onPlaceOrder;

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
                        '$itemCount item(s)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  // Bound the price so its FittedBox(scaleDown) can shrink a wide
                  // PKR total on narrow phones / large text scales instead of
                  // overflowing the summary row.
                  Flexible(
                    child: PriceWidget(price: total, currency: currency),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  label: 'Place order',
                  isLoading: isSubmitting,
                  onPressed: canPlaceOrder ? onPlaceOrder : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
