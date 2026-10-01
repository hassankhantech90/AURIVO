-- Admin dashboard figures (Requirements Doc §6: "GMV, completed orders, paid
-- orders, pending fulfilment, active sellers, refund/dispute counts and
-- payout liability"). Payout liability needs the payout ledger, which waits
-- on the payment-provider decision, so it is not computed here.
--
-- p_days: look-back window for the order figures (NULL = all time). Queue
-- counts (moderation, open disputes/returns) are always "right now".
-- GMV = sum of grand_total for orders that weren't cancelled.
CREATE OR REPLACE FUNCTION public.admin_dashboard_stats(p_days integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_from timestamptz := case when p_days is null then '-infinity'::timestamptz
                             else now() - make_interval(days => p_days) end;
  v_result jsonb;
begin
  if not has_role('admin') then
    raise exception 'Only administrators can view the dashboard.' using errcode = '42501';
  end if;

  with o as (
    select * from public.orders
    where deleted_at is null and coalesce(placed_at, created_at) >= v_from
  )
  select jsonb_build_object(
    'currency', 'PKR',
    'gmv', coalesce((select sum(grand_total) from o where status <> 'cancelled'), 0),
    'orders', (select count(*) from o),
    'completed_orders', (select count(*) from o where status in ('delivered', 'completed')),
    'paid_orders', (select count(*) from o where payment_status = 'paid'),
    'pending_fulfilment', (select count(*) from o
                           where status in ('pending', 'confirmed', 'processing', 'packed')),
    'cancelled_orders', (select count(*) from o where status = 'cancelled'),
    'refunded_orders', (select count(*) from o
                        where status = 'refunded'
                           or payment_status in ('refunded', 'partially_refunded')),
    'average_order_value', coalesce((select round(avg(grand_total), 2) from o
                                     where status <> 'cancelled'), 0),
    'active_sellers', (select count(*) from public.seller_profiles sp
                       where sp.verification_status = 'verified' and sp.deleted_at is null
                         and exists (select 1 from public.products p
                                     where p.seller_id = sp.id and p.status = 'approved'
                                       and p.deleted_at is null)),
    'open_disputes', (select count(*) from public.disputes where status = 'open'),
    'open_returns', (select count(*) from public.return_requests
                     where status in ('requested', 'approved', 'received')),
    'pending_products', (select count(*) from public.products
                         where status = 'pending' and deleted_at is null),
    'pending_sellers', (select count(*) from public.seller_profiles
                        where verification_status = 'pending' and deleted_at is null),
    'pending_businesses', (select count(*) from public.business_profiles
                           where verification_status = 'pending' and deleted_at is null),
    'daily_gmv', coalesce((
      select jsonb_agg(jsonb_build_object('day', d.day, 'gmv', d.gmv) order by d.day)
      from (
        select gs::date as day,
               coalesce((select sum(grand_total) from public.orders x
                         where x.deleted_at is null and x.status <> 'cancelled'
                           and coalesce(x.placed_at, x.created_at)::date = gs::date), 0) as gmv
        from generate_series(current_date - 13, current_date, interval '1 day') gs
      ) d), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$function$;

REVOKE ALL ON FUNCTION public.admin_dashboard_stats(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats(integer) TO authenticated;
