-- Seller insights (Requirements Doc §5: "Views, wishlist adds, conversion, top
-- products, sales by period and low-stock alerts").
--
-- product_view_daily: one counter row per product per day (small, no PII).
-- Not readable directly; written only by record_product_view and read only
-- through seller_insights.

CREATE TABLE public.product_view_daily (
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  day date NOT NULL DEFAULT current_date,
  views integer NOT NULL DEFAULT 0,
  PRIMARY KEY (product_id, day)
);
ALTER TABLE public.product_view_daily ENABLE ROW LEVEL SECURITY;
-- (no policies: no direct access for anon/authenticated)

-- Counts a product-page view. Approved products only; a seller viewing their
-- own listing isn't counted.
CREATE OR REPLACE FUNCTION public.record_product_view(p_product_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not exists (select 1 from public.products p
                 where p.id = p_product_id and p.status = 'approved'
                   and p.deleted_at is null) then
    return;
  end if;
  if exists (select 1 from public.products p
             join public.seller_profiles sp on sp.id = p.seller_id
             where p.id = p_product_id and sp.profile_id = current_profile_id()) then
    return;
  end if;
  insert into public.product_view_daily (product_id, day, views)
  values (p_product_id, current_date, 1)
  on conflict (product_id, day) do update set views = product_view_daily.views + 1;
end;
$function$;
REVOKE ALL ON FUNCTION public.record_product_view(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_product_view(uuid) TO anon, authenticated;

-- Insights for the CALLER's store over the last p_days (NULL = all time).
CREATE OR REPLACE FUNCTION public.seller_insights(p_days integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_seller uuid;
  v_from timestamptz := case when p_days is null then '-infinity'::timestamptz
                             else now() - make_interval(days => p_days) end;
  v_from_day date := case when p_days is null then '-infinity'::date
                          else current_date - p_days end;
  v_views bigint;
  v_orders bigint;
  v_result jsonb;
begin
  select sp.id into v_seller from public.seller_profiles sp
  where sp.profile_id = current_profile_id() and sp.deleted_at is null;
  if v_seller is null then
    raise exception 'You do not have a seller store.' using errcode = '42501';
  end if;

  select coalesce(sum(v.views), 0) into v_views
  from public.product_view_daily v
  join public.products p on p.id = v.product_id
  where p.seller_id = v_seller and v.day >= v_from_day;

  select count(distinct oi.order_id) into v_orders
  from public.order_items oi join public.orders o on o.id = oi.order_id
  where oi.seller_id = v_seller and o.status <> 'cancelled' and o.deleted_at is null
    and coalesce(o.placed_at, o.created_at) >= v_from;

  select jsonb_build_object(
    'currency', 'PKR',
    'views', v_views,
    'wishlist_adds', (select count(*) from public.wishlist w
                      join public.products p on p.id = w.product_id
                      where p.seller_id = v_seller and w.created_at >= v_from),
    'orders', v_orders,
    'units_sold', coalesce((select sum(oi.quantity)
                            from public.order_items oi join public.orders o on o.id = oi.order_id
                            where oi.seller_id = v_seller and o.status <> 'cancelled'
                              and o.deleted_at is null
                              and coalesce(o.placed_at, o.created_at) >= v_from), 0),
    'revenue', coalesce((select sum(oi.line_total)
                         from public.order_items oi join public.orders o on o.id = oi.order_id
                         where oi.seller_id = v_seller and o.status <> 'cancelled'
                           and o.deleted_at is null
                           and coalesce(o.placed_at, o.created_at) >= v_from), 0),
    'conversion_pct', case when v_views = 0 then null
                           else round(100.0 * v_orders / v_views, 1) end,
    'top_products', coalesce((
      select jsonb_agg(t order by t.revenue desc) from (
        select oi.product_id, max(oi.product_title_snapshot) as title,
               sum(oi.quantity) as units, sum(oi.line_total) as revenue
        from public.order_items oi join public.orders o on o.id = oi.order_id
        where oi.seller_id = v_seller and o.status <> 'cancelled' and o.deleted_at is null
          and coalesce(o.placed_at, o.created_at) >= v_from
        group by oi.product_id
        order by sum(oi.line_total) desc
        limit 5) t), '[]'::jsonb),
    'daily_revenue', coalesce((
      select jsonb_agg(jsonb_build_object('day', d.day, 'revenue', d.revenue) order by d.day)
      from (
        select gs::date as day,
               coalesce((select sum(oi.line_total)
                         from public.order_items oi join public.orders o on o.id = oi.order_id
                         where oi.seller_id = v_seller and o.status <> 'cancelled'
                           and o.deleted_at is null
                           and coalesce(o.placed_at, o.created_at)::date = gs::date), 0) as revenue
        from generate_series(current_date - 13, current_date, interval '1 day') gs) d),
      '[]'::jsonb),
    'low_stock', coalesce((
      select jsonb_agg(l order by l.available) from (
        select pv.id as variant_id, p.id as product_id, p.title, pv.sku,
               pv.stock_quantity - pv.reserved_quantity as available,
               coalesce(pv.low_stock_threshold, 2) as threshold
        from public.product_variants pv join public.products p on p.id = pv.product_id
        where p.seller_id = v_seller and p.deleted_at is null
          and pv.deleted_at is null and pv.is_active
          and pv.stock_quantity - pv.reserved_quantity <= coalesce(pv.low_stock_threshold, 2)
        order by pv.stock_quantity - pv.reserved_quantity
        limit 20) l), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$function$;
REVOKE ALL ON FUNCTION public.seller_insights(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seller_insights(integer) TO authenticated;
