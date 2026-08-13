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
  static const addresses = '/profile/addresses';
  static const seller = '/seller';
  static const sellerDetail = '/seller/:slug';

  /// Builds a concrete seller-storefront location for [slug].
  static String sellerDetailPath(String slug) => '/seller/$slug';
  // "Sell on AURIVO" onboarding — creates the current user's seller store.
  static const sellerOnboarding = '/sell';
  // Seller Studio (seller-side management). A distinct prefix so it never
  // collides with the buyer storefront route `/seller/:slug`.
  static const sellerDashboard = '/seller-studio';
  static const sellerStoreSettings = '/seller-studio/settings';
  static const sellerProductNew = '/seller-studio/new';
  static const sellerProductEdit = '/seller-studio/edit/:id';

  /// Builds a concrete seller product-edit location for [id].
  static String sellerProductEditPath(String id) => '/seller-studio/edit/$id';
  static const sellerProductVariants = '/seller-studio/variants/:id';

  /// Builds a concrete seller product-variants location for [id].
  static String sellerProductVariantsPath(String id) =>
      '/seller-studio/variants/$id';
  static const sellerProductImages = '/seller-studio/images/:id';

  /// Builds a concrete seller product-images location for [id].
  static String sellerProductImagesPath(String id) =>
      '/seller-studio/images/$id';
  static const sellerRfqInbox = '/seller-studio/rfqs';
  static const sellerRfqDetail = '/seller-studio/rfqs/:id';

  /// Builds a concrete seller RFQ-detail location for [id].
  static String sellerRfqDetailPath(String id) => '/seller-studio/rfqs/$id';

  static const wholesale = '/wholesale';
  static const rfqDetail = '/wholesale/:id';

  /// Builds a concrete RFQ-detail location for [id].
  static String rfqDetailPath(String id) => '/wholesale/$id';
  static const settings = '/settings';
  static const notifications = '/notifications';
}
