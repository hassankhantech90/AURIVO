-- Returns workflow (Requirements Doc §4.2 tracking states "Return Requested,
-- Returned, Refunded"; §6 order control: "intervene on cancellation/refund/
-- return"). Money movement waits for the payment provider: for COD orders an
-- admin records the refund manually ("mark refunded").
--
-- POLICY DEFAULTS (confirm with the founders, Doc §12):
--   * window: 7 days after the order was delivered
--   * every item in the order must be returnable (products.is_returnable)
--   * one open request per order
--
-- Lifecycle: requested -> approved | rejected | cancelled (buyer)
--            approved  -> received  (seller/admin; order -> 'returned',
--                                    reserved stock released)
--            received  -> refunded  (admin only; order -> 'refunded')
-- All writes go through SECURITY DEFINER RPCs; the table has SELECT-only RLS.

CREATE TABLE public.return_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id),
  reason text NOT NULL,
  details text,
  status text NOT NULL DEFAULT 'requested',
  resolution_note text,
  decided_by uuid REFERENCES public.profiles(id),
  decided_at timestamptz,
  received_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT return_requests_status_check CHECK (status IN
    ('requested', 'approved', 'rejected', 'received', 'refunded', 'cancelled')),
  CONSTRAINT return_requests_reason_check CHECK (reason IN
    ('damaged', 'not_as_described', 'wrong_item', 'size_fit', 'changed_mind', 'other'))
);

CREATE INDEX return_requests_order_id_idx ON public.return_requests (order_id);
CREATE INDEX return_requests_status_idx ON public.return_requests (status);
-- At most one OPEN (requested/approved/received) request per order.
CREATE UNIQUE INDEX return_requests_one_open_per_order
  ON public.return_requests (order_id)
  WHERE status IN ('requested', 'approved', 'received');

CREATE TRIGGER return_requests_set_updated_at
  BEFORE UPDATE ON public.return_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.return_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY return_requests_select ON public.return_requests
  FOR SELECT TO authenticated
  USING (
    profile_id = current_profile_id()
    OR has_role('admin')
    OR EXISTS (
      SELECT 1 FROM public.order_items oi
      JOIN public.seller_profiles sp ON sp.id = oi.seller_id
      WHERE oi.order_id = return_requests.order_id
        AND sp.profile_id = current_profile_id()
        AND sp.deleted_at IS NULL));

-- Is the caller a seller with items in this order?
CREATE OR REPLACE FUNCTION public.is_order_seller(p_order_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.order_items oi
    JOIN public.seller_profiles sp ON sp.id = oi.seller_id
    WHERE oi.order_id = p_order_id
      AND sp.profile_id = current_profile_id()
      AND sp.deleted_at IS NULL);
$$;
REVOKE ALL ON FUNCTION public.is_order_seller(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_order_seller(uuid) TO authenticated;

-- Buyer: request a return --------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_return(
  p_order_id uuid, p_reason text, p_details text DEFAULT NULL)
RETURNS public.return_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_profile uuid := current_profile_id();
  v_order public.orders;
  v_delivered_at timestamptz;
  v_row public.return_requests;
begin
  if v_profile is null then raise exception 'Authentication required.'; end if;

  select * into v_order from public.orders
  where id = p_order_id and profile_id = v_profile and deleted_at is null
  for update;
  if not found then raise exception 'Order not found.'; end if;
  if v_order.status not in ('delivered', 'completed') then
    raise exception 'Returns can be requested once the order is delivered.';
  end if;

  select max(created_at) into v_delivered_at
  from public.order_status_history
  where order_id = p_order_id and status = 'delivered';
  if coalesce(v_delivered_at, v_order.updated_at) < now() - interval '7 days' then
    raise exception 'The 7-day return window for this order has closed.';
  end if;

  if exists (
    select 1 from public.order_items oi
    join public.products p on p.id = oi.product_id
    where oi.order_id = p_order_id and not p.is_returnable
  ) then
    raise exception 'This order contains items that cannot be returned.';
  end if;

  if exists (select 1 from public.return_requests
             where order_id = p_order_id
               and status in ('requested', 'approved', 'received')) then
    raise exception 'A return is already in progress for this order.';
  end if;

  insert into public.return_requests (order_id, profile_id, reason, details)
  values (p_order_id, v_profile, p_reason, nullif(btrim(p_details), ''))
  returning * into v_row;

  -- Tell every seller in the order.
  insert into public.notifications(profile_id, type, title, body, data)
  select distinct sp.profile_id, 'seller_event', 'Return requested',
         'A buyer requested a return for order ' || v_order.order_number || '.',
         jsonb_build_object('event', 'return_requested', 'order_id', p_order_id::text,
           'return_id', v_row.id::text,
           'route', '/seller-studio/orders/' || p_order_id::text)
  from public.order_items oi
  join public.seller_profiles sp on sp.id = oi.seller_id and sp.deleted_at is null
  where oi.order_id = p_order_id;

  return v_row;
end;
$function$;

-- Buyer: withdraw a pending request ------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_return(p_return_id uuid)
RETURNS public.return_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_row public.return_requests;
begin
  update public.return_requests
  set status = 'cancelled'
  where id = p_return_id and profile_id = current_profile_id() and status = 'requested'
  returning * into v_row;
  if not found then raise exception 'This return can no longer be withdrawn.'; end if;
  return v_row;
end;
$function$;

-- Seller/admin: approve or reject ------------------------------------------------------
CREATE OR REPLACE FUNCTION public.decide_return(
  p_return_id uuid, p_approve boolean, p_note text DEFAULT NULL)
RETURNS public.return_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_row public.return_requests; v_number text;
begin
  select * into v_row from public.return_requests where id = p_return_id for update;
  if not found then raise exception 'Return not found.'; end if;
  if not (has_role('admin') or is_order_seller(v_row.order_id)) then
    raise exception 'Not allowed.' using errcode = '42501';
  end if;
  if v_row.status <> 'requested' then
    raise exception 'This return has already been decided.';
  end if;
  if not p_approve and nullif(btrim(p_note), '') is null then
    raise exception 'Please give the buyer a reason for rejecting the return.';
  end if;

  update public.return_requests
  set status = case when p_approve then 'approved' else 'rejected' end,
      resolution_note = nullif(btrim(p_note), ''),
      decided_by = current_profile_id(),
      decided_at = now()
  where id = p_return_id
  returning * into v_row;

  select order_number into v_number from public.orders where id = v_row.order_id;
  insert into public.notifications(profile_id, type, title, body, data)
  values (v_row.profile_id, 'order_update',
    case when p_approve then 'Return approved' else 'Return declined' end,
    case when p_approve
      then 'Your return for order ' || v_number || ' was approved. Please send the item back.'
      else 'Your return for order ' || v_number || ' was declined.' end,
    jsonb_build_object('event', 'return_decided', 'order_id', v_row.order_id::text,
      'return_id', v_row.id::text, 'status', v_row.status,
      'route', '/orders/' || v_row.order_id::text));
  return v_row;
end;
$function$;

-- Seller/admin: item came back -> order 'returned', release reserved stock ----------
CREATE OR REPLACE FUNCTION public.mark_return_received(p_return_id uuid)
RETURNS public.return_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_row public.return_requests;
begin
  select * into v_row from public.return_requests where id = p_return_id for update;
  if not found then raise exception 'Return not found.'; end if;
  if not (has_role('admin') or is_order_seller(v_row.order_id)) then
    raise exception 'Not allowed.' using errcode = '42501';
  end if;
  if v_row.status <> 'approved' then
    raise exception 'Only an approved return can be marked as received.';
  end if;

  update public.return_requests
  set status = 'received', received_at = now()
  where id = p_return_id
  returning * into v_row;

  -- Sold units stay reserved after delivery; a return makes them sellable.
  update public.product_variants pv
  set reserved_quantity = greatest(pv.reserved_quantity - oi.quantity, 0)
  from public.order_items oi
  where oi.order_id = v_row.order_id and pv.id = oi.product_variant_id;

  insert into public.order_status_history (order_id, status, changed_by, notes)
  values (v_row.order_id, 'returned', current_profile_id(), 'Returned item received.');
  return v_row;
end;
$function$;

-- Admin: refund recorded (manual for COD until a payment provider exists) ---------
CREATE OR REPLACE FUNCTION public.mark_return_refunded(
  p_return_id uuid, p_note text DEFAULT NULL)
RETURNS public.return_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_row public.return_requests;
begin
  if not has_role('admin') then
    raise exception 'Only an administrator can record refunds.' using errcode = '42501';
  end if;
  select * into v_row from public.return_requests where id = p_return_id for update;
  if not found then raise exception 'Return not found.'; end if;
  if v_row.status <> 'received' then
    raise exception 'Refunds are recorded after the returned item is received.';
  end if;

  update public.return_requests
  set status = 'refunded', refunded_at = now(),
      resolution_note = coalesce(nullif(btrim(p_note), ''), resolution_note)
  where id = p_return_id
  returning * into v_row;

  update public.payments set status = 'refunded'
  where order_id = v_row.order_id and deleted_at is null;
  update public.orders set payment_status = 'refunded' where id = v_row.order_id;

  insert into public.order_status_history (order_id, status, changed_by, notes)
  values (v_row.order_id, 'refunded', current_profile_id(),
          coalesce(nullif(btrim(p_note), ''), 'Refund recorded.'));
  return v_row;
end;
$function$;

REVOKE ALL ON FUNCTION public.request_return(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_return(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.decide_return(uuid, boolean, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_return_received(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_return_refunded(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_return(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_return(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_return(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_return_received(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_return_refunded(uuid, text) TO authenticated;
