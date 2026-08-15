-- Phase 12E — Safe admin order cancellation.
-- Applied live as migration 14_admin_cancel_order.
--
-- Mirrors cancel_order but gated on has_role('admin') so an admin can cancel any
-- order, releasing reserved inventory (product_variants.reserved_quantity) and
-- appending an audited order_status_history row. Restricted to pending/confirmed,
-- matching the buyer cancel_order semantics. The buyer cancel_order is unchanged.
create or replace function public.admin_cancel_order(p_order_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $body$
declare
  v_order public.orders;
begin
  if not has_role('admin') then
    raise exception 'Only an administrator can cancel orders here'
      using errcode = '42501';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id and deleted_at is null
  for update;

  if not found then
    raise exception 'Order not found.';
  end if;

  if v_order.status not in ('pending', 'confirmed') then
    raise exception 'Order can no longer be cancelled.';
  end if;

  update public.orders
  set status = 'cancelled'
  where id = p_order_id;

  update public.product_variants pv
  set reserved_quantity = greatest(pv.reserved_quantity - oi.quantity, 0)
  from public.order_items oi
  where oi.order_id = p_order_id
    and pv.id = oi.product_variant_id;

  insert into public.order_status_history (order_id, status, changed_by, notes)
  values (p_order_id, 'cancelled', public.current_profile_id(), p_reason);
end
$body$;

revoke all on function public.admin_cancel_order(uuid, text) from public;
grant execute on function public.admin_cancel_order(uuid, text) to authenticated;
