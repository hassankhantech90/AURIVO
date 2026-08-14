import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/domain/entities/auth_flow.dart';
import '../../features/authentication/presentation/forgot_password_page.dart';
import '../../features/authentication/presentation/login_page.dart';
import '../../features/authentication/presentation/onboarding_page.dart';
import '../../features/authentication/presentation/otp_page.dart';
import '../../features/authentication/presentation/password_updated_page.dart';
import '../../features/authentication/presentation/reset_password_page.dart';
import '../../features/authentication/presentation/signup_page.dart';
import '../../features/admin/presentation/admin_attribute_values_page.dart';
import '../../features/admin/presentation/admin_attributes_page.dart';
import '../../features/admin/presentation/admin_brands_page.dart';
import '../../features/admin/presentation/admin_catalog_home_page.dart';
import '../../features/admin/presentation/admin_categories_page.dart';
import '../../features/admin/presentation/admin_home_page.dart';
import '../../features/admin/presentation/admin_products_page.dart';
import '../../features/admin/presentation/admin_verifications_page.dart';
import '../../features/authentication/presentation/splash_page.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/checkout/presentation/checkout_page.dart';
import '../../features/checkout/providers/checkout_providers.dart';
import '../../features/explore/presentation/explore_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/orders/presentation/order_detail_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/products/presentation/product_page.dart';
import '../../features/profile/presentation/addresses_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/seller/presentation/seller_dashboard_page.dart';
import '../../features/seller/presentation/seller_detail_page.dart';
import '../../features/seller/presentation/seller_page.dart';
import '../../features/seller/presentation/seller_images_page.dart';
import '../../features/seller/presentation/seller_product_edit_page.dart';
import '../../features/seller/presentation/seller_onboarding_page.dart';
import '../../features/seller/presentation/seller_order_detail_page.dart';
import '../../features/seller/presentation/seller_orders_page.dart';
import '../../features/seller/presentation/seller_rfq_detail_page.dart';
import '../../features/seller/presentation/seller_rfq_inbox_page.dart';
import '../../features/seller/presentation/seller_variants_page.dart';
import '../../features/seller/presentation/store_settings_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/wholesale/presentation/rfq_detail_page.dart';
import '../../features/wholesale/presentation/wholesale_page.dart';
import '../../features/wishlist/presentation/wishlist_page.dart';
import '../theme/theme_exports.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      _fadeRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      _fadeRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      _fadeRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      _fadeRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupPage(),
      ),
      _fadeRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      _fadeRoute(
        path: AppRoutes.otp,
        name: 'otp',
        builder: (context, state) {
          final flow = state.uri.queryParameters['flow'] == 'forgotPassword'
              ? AuthFlow.forgotPassword
              : AuthFlow.signup;
          return OtpPage(flow: flow);
        },
      ),
      _fadeRoute(
        path: AppRoutes.resetPassword,
        name: 'resetPassword',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      _fadeRoute(
        path: AppRoutes.passwordUpdated,
        name: 'passwordUpdated',
        builder: (context, state) => const PasswordUpdatedPage(),
      ),
      _fadeRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      _fadeRoute(
        path: AppRoutes.explore,
        name: 'explore',
        builder: (context, state) => const ExplorePage(),
      ),
      _fadeRoute(
        path: AppRoutes.product,
        name: 'product',
        builder: (context, state) =>
            ProductPage(productId: state.pathParameters['id'] ?? ''),
      ),
      _fadeRoute(
        path: AppRoutes.cart,
        name: 'cart',
        builder: (context, state) => const CartPage(),
      ),
      _fadeRoute(
        path: AppRoutes.checkout,
        name: 'checkout',
        builder: (context, state) => const CheckoutPage(),
        // Guests may keep a cart but cannot check out — hard-redirect to login.
        redirect: (context, state) =>
            ref.read(checkoutRepositoryProvider).isAuthenticated
            ? null
            : AppRoutes.login,
      ),
      _fadeRoute(
        path: AppRoutes.orders,
        name: 'orders',
        builder: (context, state) => const OrdersPage(),
      ),
      _fadeRoute(
        path: AppRoutes.orderDetail,
        name: 'orderDetail',
        builder: (context, state) =>
            OrderDetailPage(orderId: state.pathParameters['id'] ?? ''),
      ),
      _fadeRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      _fadeRoute(
        path: AppRoutes.addresses,
        name: 'addresses',
        builder: (context, state) => const AddressesPage(),
      ),
      _fadeRoute(
        path: AppRoutes.wishlist,
        name: 'wishlist',
        builder: (context, state) => const WishlistPage(),
      ),
      _fadeRoute(
        path: AppRoutes.seller,
        name: 'seller',
        builder: (context, state) => const SellerPage(),
      ),
      _fadeRoute(
        path: AppRoutes.sellerDetail,
        name: 'sellerDetail',
        builder: (context, state) =>
            SellerDetailPage(slug: state.pathParameters['slug'] ?? ''),
      ),
      _fadeRoute(
        path: AppRoutes.sellerOnboarding,
        name: 'sellerOnboarding',
        builder: (context, state) => const SellerOnboardingPage(),
      ),
      _fadeRoute(
        path: AppRoutes.sellerStoreSettings,
        name: 'sellerStoreSettings',
        builder: (context, state) => const StoreSettingsPage(),
      ),
      _fadeRoute(
        path: AppRoutes.sellerDashboard,
        name: 'sellerDashboard',
        builder: (context, state) => const SellerDashboardPage(),
      ),
      _fadeRoute(
        path: AppRoutes.sellerProductNew,
        name: 'sellerProductNew',
        builder: (context, state) => const SellerProductEditPage(),
      ),
      _fadeRoute(
        path: AppRoutes.sellerProductEdit,
        name: 'sellerProductEdit',
        builder: (context, state) =>
            SellerProductEditPage(productId: state.pathParameters['id']),
      ),
      _fadeRoute(
        path: AppRoutes.sellerProductVariants,
        name: 'sellerProductVariants',
        builder: (context, state) =>
            SellerVariantsPage(productId: state.pathParameters['id'] ?? ''),
      ),
      _fadeRoute(
        path: AppRoutes.sellerProductImages,
        name: 'sellerProductImages',
        builder: (context, state) =>
            SellerImagesPage(productId: state.pathParameters['id'] ?? ''),
      ),
      _fadeRoute(
        path: AppRoutes.sellerOrders,
        name: 'sellerOrders',
        builder: (context, state) => const SellerOrdersPage(),
      ),
      _fadeRoute(
        path: AppRoutes.sellerOrderDetail,
        name: 'sellerOrderDetail',
        builder: (context, state) =>
            SellerOrderDetailPage(orderId: state.pathParameters['id'] ?? ''),
      ),
      _fadeRoute(
        path: AppRoutes.sellerRfqInbox,
        name: 'sellerRfqInbox',
        builder: (context, state) => const SellerRfqInboxPage(),
      ),
      _fadeRoute(
        path: AppRoutes.sellerRfqDetail,
        name: 'sellerRfqDetail',
        builder: (context, state) =>
            SellerRfqDetailPage(rfqId: state.pathParameters['id'] ?? ''),
      ),
      _fadeRoute(
        path: AppRoutes.wholesale,
        name: 'wholesale',
        builder: (context, state) => const WholesalePage(),
      ),
      _fadeRoute(
        path: AppRoutes.rfqDetail,
        name: 'rfqDetail',
        builder: (context, state) =>
            RfqDetailPage(rfqId: state.pathParameters['id'] ?? ''),
      ),
      _fadeRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      _fadeRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      _fadeRoute(
        path: AppRoutes.admin,
        name: 'admin',
        builder: (context, state) => const AdminHomePage(),
      ),
      _fadeRoute(
        path: AppRoutes.adminVerifications,
        name: 'adminVerifications',
        builder: (context, state) => const AdminVerificationsPage(),
      ),
      _fadeRoute(
        path: AppRoutes.adminProducts,
        name: 'adminProducts',
        builder: (context, state) => const AdminProductsPage(),
      ),
      _fadeRoute(
        path: AppRoutes.adminCatalog,
        name: 'adminCatalog',
        builder: (context, state) => const AdminCatalogHomePage(),
      ),
      _fadeRoute(
        path: AppRoutes.adminCategories,
        name: 'adminCategories',
        builder: (context, state) => const AdminCategoriesPage(),
      ),
      _fadeRoute(
        path: AppRoutes.adminBrands,
        name: 'adminBrands',
        builder: (context, state) => const AdminBrandsPage(),
      ),
      _fadeRoute(
        path: AppRoutes.adminAttributes,
        name: 'adminAttributes',
        builder: (context, state) => const AdminAttributesPage(),
      ),
      _fadeRoute(
        path: AppRoutes.adminAttributeValues,
        name: 'adminAttributeValues',
        builder: (context, state) => AdminAttributeValuesPage(
          attributeId: state.pathParameters['id'] ?? '',
          attributeName: state.extra as String?,
        ),
      ),
    ],
  );
});

GoRoute _fadeRoute({
  required String path,
  required String name,
  required Widget Function(BuildContext context, GoRouterState state) builder,
  GoRouterRedirect? redirect,
}) {
  return GoRoute(
    path: path,
    name: name,
    redirect: redirect,
    pageBuilder: (context, state) {
      return CustomTransitionPage<void>(
        key: state.pageKey,
        transitionDuration: AppDurations.normal,
        reverseTransitionDuration: AppDurations.fast,
        child: builder(context, state),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppAnimations.standard,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
    },
  );
}
