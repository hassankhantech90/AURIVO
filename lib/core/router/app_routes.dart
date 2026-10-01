class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const otp = '/otp';
  static const verifyEmail = '/verify-email';
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
  static const businessAccount = '/business';
  static const wishlist = '/wishlist';
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
  static const sellerProductTiers = '/seller-studio/tiers/:id';

  /// Builds a concrete seller wholesale-tiers location for [id].
  static String sellerProductTiersPath(String id) =>
      '/seller-studio/tiers/$id';
  static const sellerRfqInbox = '/seller-studio/rfqs';
  static const sellerRfqDetail = '/seller-studio/rfqs/:id';

  /// Builds a concrete seller RFQ-detail location for [id].
  static String sellerRfqDetailPath(String id) => '/seller-studio/rfqs/$id';
  static const sellerInsights = '/seller-studio/insights';
  static const sellerOrders = '/seller-studio/orders';
  static const sellerOrderDetail = '/seller-studio/orders/:id';

  /// Builds a concrete seller order-detail location for [id].
  static String sellerOrderDetailPath(String id) =>
      '/seller-studio/orders/$id';

  static const wholesale = '/wholesale';
  static const rfqDetail = '/wholesale/:id';

  /// Builds a concrete RFQ-detail location for [id].
  static String rfqDetailPath(String id) => '/wholesale/$id';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const support = '/support';
  static const messages = '/messages';
  static const messageThread = '/messages/:id';

  /// Builds a concrete conversation-thread location for [conversationId].
  static String messageThreadPath(String conversationId) =>
      '/messages/$conversationId';

  // Admin console (gated on the `admin` role via has_role).
  static const admin = '/admin';
  static const adminVerifications = '/admin/verifications';
  static const adminBusinessVerifications = '/admin/business-verifications';
  static const adminProducts = '/admin/products';
  static const adminCatalog = '/admin/catalog';
  static const adminCategories = '/admin/catalog/categories';
  static const adminBrands = '/admin/catalog/brands';
  static const adminAttributes = '/admin/catalog/attributes';
  static const adminAttributeValues = '/admin/catalog/attributes/:id/values';

  /// Builds a concrete attribute-values location for [attributeId].
  static String adminAttributeValuesPath(String attributeId) =>
      '/admin/catalog/attributes/$attributeId/values';
  static const adminCoupons = '/admin/coupons';
  static const adminCouponRedemptions = '/admin/coupons/:id/redemptions';

  /// Builds a concrete coupon-redemptions location for [couponId].
  static String adminCouponRedemptionsPath(String couponId) =>
      '/admin/coupons/$couponId/redemptions';
  static const adminUsers = '/admin/users';
  static const adminUserDetail = '/admin/users/:id';

  /// Builds a concrete user-detail location for [profileId].
  static String adminUserDetailPath(String profileId) =>
      '/admin/users/$profileId';
  static const adminOrders = '/admin/orders';
  static const adminOrderDetail = '/admin/orders/:id';

  /// Builds a concrete admin order-detail location for [orderId].
  static String adminOrderDetailPath(String orderId) => '/admin/orders/$orderId';
  static const adminSupport = '/admin/support';
  static const adminSupportDetail = '/admin/support/:id';

  /// Builds a concrete admin ticket-detail location for [ticketId].
  static String adminSupportDetailPath(String ticketId) =>
      '/admin/support/$ticketId';
  static const adminDisputes = '/admin/disputes';
  static const adminContent = '/admin/content';

  // Help centre & CMS pages (public).
  static const help = '/help';
  static const cmsPage = '/pages/:slug';
  static String cmsPagePath(String slug) => '/pages/$slug';

  // Disputes (buyer, the order's sellers and admins share one thread).
  static const disputeDetail = '/disputes/:id';
  static String disputeDetailPath(String disputeId) => '/disputes/$disputeId';
}
