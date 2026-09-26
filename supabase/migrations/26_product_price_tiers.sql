-- Wholesale price tiers: per-product "buy N+ at unit_price" breaks.
-- Currency is inherited from the parent product (no per-tier currency).
CREATE TABLE public.product_price_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  min_quantity integer NOT NULL,
  unit_price numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT product_price_tiers_min_quantity_positive CHECK (min_quantity > 0),
  CONSTRAINT product_price_tiers_unit_price_nonneg CHECK (unit_price >= 0),
  CONSTRAINT product_price_tiers_unique_qty UNIQUE (product_id, min_quantity)
);

CREATE INDEX product_price_tiers_product_id_idx
  ON public.product_price_tiers (product_id);

ALTER TABLE public.product_price_tiers ENABLE ROW LEVEL SECURITY;

-- Public read for tiers of visible (approved, non-deleted) products.
CREATE POLICY product_price_tiers_public_select
  ON public.product_price_tiers FOR SELECT
  TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.products p
    WHERE p.id = product_price_tiers.product_id
      AND p.status = 'approved'
      AND p.deleted_at IS NULL));

-- Sellers (and admins) manage tiers for their own products.
CREATE POLICY product_price_tiers_seller_all_own
  ON public.product_price_tiers FOR ALL
  TO authenticated
  USING (has_role('admin') OR EXISTS (
    SELECT 1 FROM public.products p
    JOIN public.seller_profiles sp ON sp.id = p.seller_id
    WHERE p.id = product_price_tiers.product_id
      AND sp.profile_id = current_profile_id()
      AND p.deleted_at IS NULL
      AND sp.deleted_at IS NULL))
  WITH CHECK (has_role('admin') OR EXISTS (
    SELECT 1 FROM public.products p
    JOIN public.seller_profiles sp ON sp.id = p.seller_id
    WHERE p.id = product_price_tiers.product_id
      AND sp.profile_id = current_profile_id()
      AND p.deleted_at IS NULL
      AND sp.deleted_at IS NULL));
