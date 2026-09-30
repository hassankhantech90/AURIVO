-- Wholesale prices are hidden until the buyer is business-verified
-- (Requirements Doc: "Wholesale price is hidden until the buyer is
-- business-verified"). Retail prices stay public.

-- True when the current user owns a verified, non-deleted business profile.
CREATE OR REPLACE FUNCTION public.is_verified_business()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.business_profiles b
    WHERE b.profile_id = current_profile_id()
      AND b.verification_status = 'verified'
      AND b.deleted_at IS NULL);
$$;

REVOKE ALL ON FUNCTION public.is_verified_business() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_verified_business() TO authenticated;

-- Tier prices: verified businesses only (sellers/admins keep access through
-- product_price_tiers_seller_all_own).
DROP POLICY IF EXISTS product_price_tiers_public_select ON public.product_price_tiers;

CREATE POLICY product_price_tiers_verified_business_select
  ON public.product_price_tiers FOR SELECT
  TO authenticated
  USING (public.is_verified_business() AND EXISTS (
    SELECT 1 FROM public.products p
    WHERE p.id = product_price_tiers.product_id
      AND p.status = 'approved'
      AND p.deleted_at IS NULL));

-- Which visible products offer wholesale tiers — ids only, never prices — so
-- the Home Wholesale rail works for every visitor.
CREATE OR REPLACE FUNCTION public.wholesale_product_ids()
RETURNS TABLE (product_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT t.product_id
  FROM public.product_price_tiers t
  JOIN public.products p ON p.id = t.product_id
  WHERE p.status = 'approved'
    AND p.deleted_at IS NULL;
$$;

REVOKE ALL ON FUNCTION public.wholesale_product_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wholesale_product_ids() TO anon, authenticated;
