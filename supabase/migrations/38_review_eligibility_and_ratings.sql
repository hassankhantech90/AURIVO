-- Reviews (Requirements Doc §3): "Only buyers with a delivered, non-refunded
-- order may submit one review per order item; admins can moderate abuse."
--
-- 1. product_reviews INSERT (non-admin) must reference the reviewer's own
--    order item for that product on a delivered/completed order (refunded /
--    returned orders have their own statuses, so they don't qualify). On
--    UPDATE a non-admin can't swap the order item or touch helpful_count.
-- 2. seller_reviews INSERT (non-admin) requires a delivered/completed order
--    containing that seller's items.
-- 3. Eligibility helpers for the app: reviewable_order_item(product) and
--    can_review_seller(seller).
-- 4. Ratings were never recalculated. products / seller_profiles
--    rating_average + rating_count are now maintained from APPROVED,
--    non-deleted reviews by AFTER triggers (using the aurivo.system_write
--    flag from migration 35, reset immediately after), and backfilled.

-- Eligibility helpers ---------------------------------------------------------

CREATE OR REPLACE FUNCTION public.reviewable_order_item(p_product_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT oi.id
  FROM public.order_items oi
  JOIN public.orders o ON o.id = oi.order_id
  WHERE oi.product_id = p_product_id
    AND o.profile_id = current_profile_id()
    AND o.status IN ('delivered', 'completed')
    AND o.deleted_at IS NULL
  ORDER BY o.created_at DESC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.can_review_seller(p_seller_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.order_items oi
    JOIN public.orders o ON o.id = oi.order_id
    WHERE oi.seller_id = p_seller_profile_id
      AND o.profile_id = current_profile_id()
      AND o.status IN ('delivered', 'completed')
      AND o.deleted_at IS NULL);
$$;

REVOKE ALL ON FUNCTION public.reviewable_order_item(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_review_seller(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reviewable_order_item(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_review_seller(uuid) TO authenticated;

-- Integrity triggers ----------------------------------------------------------

CREATE OR REPLACE FUNCTION public.enforce_product_review_integrity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_admin boolean := public.has_role('admin');
begin
  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.helpful_count := 0;
    if not v_admin and auth.uid() is not null then
      if new.order_item_id is null or not exists (
        select 1
        from public.order_items oi
        join public.orders o on o.id = oi.order_id
        where oi.id = new.order_item_id
          and oi.product_id = new.product_id
          and o.profile_id = new.profile_id
          and o.status in ('delivered', 'completed')
          and o.deleted_at is null
      ) then
        raise exception 'Only buyers who have received this item can review it.'
          using errcode = '42501';
      end if;
    end if;
  elsif not v_admin then
    new.status := 'pending';
    new.order_item_id := old.order_item_id;
    new.helpful_count := old.helpful_count;
  end if;

  if new.order_item_id is not null then
    new.verified_purchase := exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.id = new.order_item_id
        and oi.product_id = new.product_id
        and o.profile_id = new.profile_id
        and o.status in ('delivered', 'completed')
        and o.deleted_at is null
    );
  else
    new.verified_purchase := false;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.enforce_seller_review_integrity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_admin boolean := public.has_role('admin');
begin
  if tg_op = 'INSERT' then
    new.status := 'pending';
  elsif not v_admin then
    new.status := 'pending';
  end if;

  new.verified_purchase := exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.seller_id = new.seller_profile_id
      and o.profile_id = new.profile_id
      and o.status in ('delivered', 'completed')
      and o.deleted_at is null
  );

  if tg_op = 'INSERT' and not v_admin and auth.uid() is not null
     and not new.verified_purchase then
    raise exception 'Only buyers who have received an order from this store can review it.'
      using errcode = '42501';
  end if;

  return new;
end;
$function$;

-- Rating aggregation ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.refresh_product_rating(p_product_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  perform set_config('aurivo.system_write', 'on', true);
  update public.products p
  set rating_average = coalesce(s.avg_rating, 0),
      rating_count = coalesce(s.cnt, 0)
  from (
    select round(avg(r.rating)::numeric, 2) as avg_rating, count(*)::int as cnt
    from public.product_reviews r
    where r.product_id = p_product_id
      and r.status = 'approved'
      and r.deleted_at is null
  ) s
  where p.id = p_product_id;
  perform set_config('aurivo.system_write', 'off', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_seller_rating(p_seller_profile_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  perform set_config('aurivo.system_write', 'on', true);
  update public.seller_profiles sp
  set rating_average = coalesce(s.avg_rating, 0),
      rating_count = coalesce(s.cnt, 0)
  from (
    select round(avg(r.rating)::numeric, 2) as avg_rating, count(*)::int as cnt
    from public.seller_reviews r
    where r.seller_profile_id = p_seller_profile_id
      and r.status = 'approved'
      and r.deleted_at is null
  ) s
  where sp.id = p_seller_profile_id;
  perform set_config('aurivo.system_write', 'off', true);
end;
$function$;

REVOKE ALL ON FUNCTION public.refresh_product_rating(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_seller_rating(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.on_product_review_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_product_rating(old.product_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE')
     and (tg_op = 'INSERT' or new.product_id is distinct from old.product_id) then
    perform public.refresh_product_rating(new.product_id);
  end if;
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.on_seller_review_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_seller_rating(old.seller_profile_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE')
     and (tg_op = 'INSERT' or new.seller_profile_id is distinct from old.seller_profile_id) then
    perform public.refresh_seller_rating(new.seller_profile_id);
  end if;
  return null;
end;
$function$;

DROP TRIGGER IF EXISTS product_reviews_refresh_rating ON public.product_reviews;
CREATE TRIGGER product_reviews_refresh_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.product_reviews
  FOR EACH ROW EXECUTE FUNCTION public.on_product_review_change();

DROP TRIGGER IF EXISTS seller_reviews_refresh_rating ON public.seller_reviews;
CREATE TRIGGER seller_reviews_refresh_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.seller_reviews
  FOR EACH ROW EXECUTE FUNCTION public.on_seller_review_change();

-- Backfill: replace seeded/stale ratings with the real approved-review values.
DO $$
declare r record;
begin
  for r in select id from public.products loop
    perform public.refresh_product_rating(r.id);
  end loop;
  for r in select id from public.seller_profiles loop
    perform public.refresh_seller_rating(r.id);
  end loop;
end $$;
