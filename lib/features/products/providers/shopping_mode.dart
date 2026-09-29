import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the buyer is browsing the retail catalogue or the wholesale
/// catalogue (products that offer tiered/bulk pricing). Toggled from the Home
/// header; session-scoped (defaults to retail on each launch).
enum ShoppingMode { retail, wholesale }

final shoppingModeProvider = StateProvider<ShoppingMode>(
  (ref) => ShoppingMode.retail,
);
