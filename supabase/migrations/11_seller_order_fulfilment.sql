-- Phase 11 — Seller Order Fulfilment
-- Applied live as migration version 20260814004536 (name: 11_seller_order_fulfilment).
--
-- 1) Fix shipments_seller_manage_own WITH CHECK: the original used the
--    tautology (oi.order_id = oi.order_id), letting any seller create/repoint a
--    shipment to an arbitrary order. Scope it to shipments.order_id (mirror USING).
alter policy shipments_seller_manage_own on public.shipments
with check (
  exists (
    select 1
    from public.order_items oi
    join public.seller_profiles sp on sp.id = oi.seller_id
    where oi.order_id = shipments.order_id
      and sp.profile_id = current_profile_id()
      and sp.deleted_at is null
  )
);

-- 2) Tighten quotes_seller_insert: besides owning the seller_profile_id, the
--    target RFQ must be visible to this seller (RLS-filtered), non-deleted, and
--    still soliciting quotes (open/quoted). Blocks blind-quoting arbitrary or
--    closed RFQs.
alter policy quotes_seller_insert on public.quotes
with check (
  has_role('admin') or (
    exists (
      select 1 from public.seller_profiles sp
      where sp.id = quotes.seller_profile_id
        and sp.profile_id = current_profile_id()
        and sp.deleted_at is null
    )
    and exists (
      select 1 from public.rfqs r
      where r.id = quotes.rfq_id
        and r.deleted_at is null
        and r.status in ('open', 'quoted')
    )
  )
);

-- 3) The old quotes_seller_update_delete was cmd=ALL, so it also acted as a
--    permissive INSERT policy whose check only required seller ownership —
--    bypassing (2). Split it into UPDATE and DELETE so INSERT is governed solely
--    by quotes_seller_insert.
drop policy quotes_seller_update_delete on public.quotes;

create policy quotes_seller_update on public.quotes
for update
using (
  has_role('admin') or exists (
    select 1 from public.seller_profiles sp
    where sp.id = quotes.seller_profile_id
      and sp.profile_id = current_profile_id()
      and sp.deleted_at is null
  )
)
with check (
  has_role('admin') or exists (
    select 1 from public.seller_profiles sp
    where sp.id = quotes.seller_profile_id
      and sp.profile_id = current_profile_id()
      and sp.deleted_at is null
  )
);

create policy quotes_seller_delete on public.quotes
for delete
using (
  has_role('admin') or exists (
    select 1 from public.seller_profiles sp
    where sp.id = quotes.seller_profile_id
      and sp.profile_id = current_profile_id()
      and sp.deleted_at is null
  )
);

-- 4) Privacy-preserving seller order reads (SECURITY DEFINER). Sellers have no
--    RLS SELECT on orders; these RPCs expose ONLY fulfilment-necessary fields
--    for orders containing the caller's own items — never other sellers' totals
--    or the billing snapshot. Line items and shipments remain read through the
--    existing seller-scoped RLS.
create or replace function public.seller_orders()
returns table (
  order_id uuid,
  order_number text,
  status text,
  currency text,
  placed_at timestamptz,
  item_count bigint,
  seller_subtotal numeric
)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select o.id, o.order_number, o.status, o.currency, o.placed_at,
         count(oi.id) as item_count,
         coalesce(sum(oi.line_total), 0) as seller_subtotal
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  join public.seller_profiles sp on sp.id = oi.seller_id
  where sp.profile_id = current_profile_id()
    and sp.deleted_at is null
    and o.deleted_at is null
  group by o.id, o.order_number, o.status, o.currency, o.placed_at
  order by o.placed_at desc
$$;

create or replace function public.seller_order_header(p_order_id uuid)
returns table (
  order_id uuid,
  order_number text,
  status text,
  currency text,
  placed_at timestamptz,
  shipping_address_snapshot jsonb
)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select o.id, o.order_number, o.status, o.currency, o.placed_at,
         o.shipping_address_snapshot
  from public.orders o
  where o.id = p_order_id
    and o.deleted_at is null
    and exists (
      select 1
      from public.order_items oi
      join public.seller_profiles sp on sp.id = oi.seller_id
      where oi.order_id = o.id
        and sp.profile_id = current_profile_id()
        and sp.deleted_at is null
    )
$$;

revoke all on function public.seller_orders() from public;
revoke all on function public.seller_order_header(uuid) from public;
grant execute on function public.seller_orders() to authenticated;
grant execute on function public.seller_order_header(uuid) to authenticated;
