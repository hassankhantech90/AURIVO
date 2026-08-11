class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const otp = '/otp';
  static const resetPassword = '/reset-password';
  static const passwordUpdated = '/password-updated';
  static const home = '/home';
  static const explore = '/explore';
  static const product = '/product/:id';

  /// Builds a concrete product-detail location for [id].
  static String productPath(String id) => '/product/$id';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const orderDetail = '/orders/:id';

  /// Builds a concrete order-detail location for [id].
  static String orderDetailPath(String id) => '/orders/$id';
  static const profile = '/profile';
  static const seller = '/seller';
  static const sellerDetail = '/seller/:slug';

  /// Builds a concrete seller-storefront location for [slug].
  static String sellerDetailPath(String slug) => '/seller/$slug';
  static const wholesale = '/wholesale';
  static const settings = '/settings';
  static const notifications = '/notifications';
}
