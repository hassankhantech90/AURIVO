-- Catalogue search across product title, brand name and maker (seller store
-- name). Returns ids only; the app then loads the products through the normal
-- list query so every other filter, sort and pagination still applies.
--
-- SECURITY INVOKER: RLS on products/brands/seller_profiles applies as usual,
-- so only visible products match, and a hidden brand or unverified store
-- simply never matches (its LEFT JOIN side is null). LIKE wildcards in the
-- user text are escaped so '%' / '_' are matched literally.
CREATE OR REPLACE FUNCTION public.search_product_ids(p_query text)
RETURNS TABLE (product_id uuid)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH q AS (
    SELECT '%' || replace(replace(replace(btrim(coalesce(p_query, '')),
             '\', '\\'), '%', '\%'), '_', '\_') || '%' AS pat
  )
  SELECT p.id
  FROM public.products p
  CROSS JOIN q
  LEFT JOIN public.brands b ON b.id = p.brand_id
  LEFT JOIN public.seller_profiles s ON s.id = p.seller_id
  WHERE btrim(coalesce(p_query, '')) <> ''
    AND (p.title ILIKE q.pat
         OR b.name ILIKE q.pat
         OR s.store_name ILIKE q.pat);
$$;

REVOKE ALL ON FUNCTION public.search_product_ids(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_product_ids(text) TO anon, authenticated;
