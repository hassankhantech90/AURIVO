/// Seller-supplied values for creating or editing a wholesale price tier.
/// The parent product and currency are never taken from this draft — ownership
/// is enforced by RLS and the currency is the product's.
class PriceTierDraft {
  const PriceTierDraft({required this.minQuantity, required this.unitPrice});

  final int minQuantity;
  final double unitPrice;
}
