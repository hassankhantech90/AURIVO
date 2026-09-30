-- Explore filters (Requirements Doc §4.1): price range and purity/karat.
-- Returns ids only; the app intersects them into the shared id filter so they
-- compose with category / metal / search / wholesale / sort / pagination.
-- SECURITY INVOKER: RLS decides visibility as usual.
CREATE OR REPLACE FUNCTION public.filter_product_ids(
  p_min_price numeric DEFAULT NULL,
  p_max_price numeric DEFAULT NULL,
  p_purity text DEFAULT NULL
)
RETURNS TABLE (product_id uuid)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT p.id
  FROM public.products p
  WHERE (p_min_price IS NULL OR p.base_price >= p_min_price)
    AND (p_max_price IS NULL OR p.base_price <= p_max_price)
    AND (nullif(btrim(p_purity), '') IS NULL
         OR lower(btrim(p.purity)) = lower(btrim(p_purity)));
$$;

REVOKE ALL ON FUNCTION public.filter_product_ids(numeric, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.filter_product_ids(numeric, numeric, text) TO anon, authenticated;
