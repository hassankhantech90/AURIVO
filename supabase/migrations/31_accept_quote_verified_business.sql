-- Re-gate quote acceptance on a CURRENTLY verified business. RFQ creation is
-- already gated (migration 29), but a business suspended/rejected after
-- requesting could otherwise still convert an open quote into an order.
-- Identical to migration 27 except for the is_verified_business() check.
CREATE OR REPLACE FUNCTION public.accept_quote(p_quote_id uuid, p_address_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_profile_id uuid;
  v_quote public.quotes;
  v_rfq public.rfqs;
  v_address public.addresses;
  v_variant record;
  v_order_id uuid;
  v_quantity int;
  v_unit_price numeric(12,2);
  v_line_total numeric(12,2);
  v_address_snapshot jsonb;
begin
  v_profile_id := public.current_profile_id();
  if v_profile_id is null then
    raise exception 'Authentication required.';
  end if;
  if not public.is_verified_business() then
    raise exception 'A verified business is required to accept wholesale quotes.';
  end if;

  select * into v_quote from public.quotes
  where id = p_quote_id and deleted_at is null
  for update;
  if not found then raise exception 'Quote not found.'; end if;

  select * into v_rfq from public.rfqs
  where id = v_quote.rfq_id and deleted_at is null
  for update;
  if not found then raise exception 'Request not found.'; end if;

  if v_rfq.buyer_profile_id <> v_profile_id then
    raise exception 'You can only accept quotes on your own requests.';
  end if;
  if v_quote.status <> 'sent' then
    raise exception 'This quote can no longer be accepted.';
  end if;
  if v_rfq.status not in ('open', 'quoted') then
    raise exception 'This request is no longer open.';
  end if;
  if v_quote.valid_until is not null and v_quote.valid_until < now() then
    raise exception 'This quote has expired.';
  end if;
  if v_rfq.product_id is null then
    raise exception 'This request is not linked to a product and cannot be ordered automatically.';
  end if;

  v_quantity := v_rfq.quantity;
  if v_quantity < v_quote.minimum_order_quantity then
    raise exception 'This quote requires a minimum of % units.', v_quote.minimum_order_quantity;
  end if;

  select * into v_address from public.addresses
  where id = p_address_id and profile_id = v_profile_id and deleted_at is null;
  if not found then raise exception 'Address not found for this profile.'; end if;

  -- Resolve a concrete variant: the RFQ's if set, else the product's cheapest
  -- active variant. order_items requires a variant.
  select pv.id, pv.sku, pv.stock_quantity, pv.reserved_quantity,
         p.id as product_id, p.title as product_title, p.seller_id as seller_id,
         (select pi.storage_path from public.product_images pi
          where pi.product_id = p.id and pi.is_primary = true and pi.deleted_at is null
          limit 1) as image_path
  into v_variant
  from public.product_variants pv
  join public.products p on p.id = pv.product_id
  where p.id = v_rfq.product_id
    and pv.is_active = true and pv.deleted_at is null
    and (v_rfq.product_variant_id is null or pv.id = v_rfq.product_variant_id)
  order by (pv.id = v_rfq.product_variant_id) desc, pv.price asc
  limit 1;
  if v_variant.id is null then
    raise exception 'The product for this request is no longer available.';
  end if;

  if v_variant.seller_id <> v_quote.seller_profile_id then
    raise exception 'Quote seller does not match the product seller.';
  end if;
  if v_variant.stock_quantity - v_variant.reserved_quantity < v_quantity then
    raise exception 'Insufficient stock for %.', v_variant.product_title;
  end if;

  v_unit_price := v_quote.unit_price;
  v_line_total := v_unit_price * v_quantity;

  v_address_snapshot := jsonb_build_object(
    'recipient_name', v_address.recipient_name,
    'phone', v_address.phone,
    'address_line_1', v_address.address_line_1,
    'address_line_2', v_address.address_line_2,
    'area', v_address.area,
    'city', v_address.city,
    'province', v_address.province,
    'postal_code', v_address.postal_code,
    'country', v_address.country
  );

  insert into public.orders (
    order_number, profile_id, address_id, currency,
    subtotal, shipping_fee, discount_total, tax_total, grand_total,
    shipping_address_snapshot, billing_address_snapshot, notes
  ) values (
    public.generate_order_number(), v_profile_id, p_address_id, v_quote.currency,
    v_line_total, 0, 0, 0, v_line_total,
    v_address_snapshot, v_address_snapshot, 'Wholesale order from accepted quote.'
  ) returning id into v_order_id;

  insert into public.order_items (
    order_id, product_id, product_variant_id, seller_id,
    product_title_snapshot, sku_snapshot, image_path_snapshot,
    unit_price, quantity, line_total, currency
  ) values (
    v_order_id, v_variant.product_id, v_variant.id, v_variant.seller_id,
    v_variant.product_title, v_variant.sku, v_variant.image_path,
    v_unit_price, v_quantity, v_line_total, v_quote.currency
  );

  update public.product_variants
  set reserved_quantity = reserved_quantity + v_quantity
  where id = v_variant.id;

  insert into public.payments (order_id, provider, method, status, amount, currency)
  values (v_order_id, 'manual', 'cash_on_delivery', 'pending', v_line_total, v_quote.currency);

  insert into public.order_status_history (order_id, status, changed_by, notes)
  values (v_order_id, 'pending', v_profile_id, 'Order placed from accepted quote.');

  update public.quotes set status = 'accepted' where id = v_quote.id;
  update public.quotes set status = 'rejected'
    where rfq_id = v_rfq.id and id <> v_quote.id and status = 'sent';
  update public.rfqs set status = 'accepted' where id = v_rfq.id;

  return v_order_id;
end;
$function$;
