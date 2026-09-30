-- Server-authoritative cart line pricing + wholesale tier pricing in the cart.
--
-- 1. SECURITY: cart_items_owner_update lets a buyer update any column of their
--    own lines, including unit_price_snapshot, which checkout_cart trusts. The
--    BEFORE trigger below recomputes the price on every insert/update, so a
--    client-supplied price is always overwritten.
-- 2. WHOLESALE: when the cart owner is a verified business and the line
--    quantity reaches a product_price_tiers minimum, the line is priced at the
--    best qualifying tier (only if it is lower than the variant price).
-- 3. checkout_cart re-prices every line right before totalling, so a business
--    verified after adding items gets tier prices and stale prices can't pass.
--    Otherwise identical to the previous checkout_cart.

CREATE OR REPLACE FUNCTION public.price_cart_item()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_price numeric(12,2);
  v_currency text;
  v_product_id uuid;
  v_owner uuid;
  v_tier numeric(12,2);
begin
  select pv.price, coalesce(pv.currency, 'PKR'), pv.product_id
    into v_price, v_currency, v_product_id
  from public.product_variants pv
  where pv.id = NEW.product_variant_id;
  if not found then
    raise exception 'This item is not available.';
  end if;

  select c.profile_id into v_owner from public.carts c where c.id = NEW.cart_id;

  if v_owner is not null and exists (
    select 1 from public.business_profiles b
    where b.profile_id = v_owner
      and b.verification_status = 'verified'
      and b.deleted_at is null
  ) then
    select t.unit_price into v_tier
    from public.product_price_tiers t
    where t.product_id = v_product_id and t.min_quantity <= NEW.quantity
    order by t.min_quantity desc
    limit 1;
    if v_tier is not null and v_tier < v_price then
      v_price := v_tier;
    end if;
  end if;

  NEW.unit_price_snapshot := v_price;
  NEW.currency := v_currency;
  return NEW;
end;
$function$;

DROP TRIGGER IF EXISTS cart_items_price_line ON public.cart_items;
CREATE TRIGGER cart_items_price_line
  BEFORE INSERT OR UPDATE ON public.cart_items
  FOR EACH ROW EXECUTE FUNCTION public.price_cart_item();

CREATE OR REPLACE FUNCTION public.checkout_cart(p_cart_id uuid, p_address_id uuid, p_payment_method text DEFAULT 'cash_on_delivery'::text, p_notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_profile_id uuid;
  v_cart public.carts;
  v_address public.addresses;
  v_order_id uuid;
  v_subtotal numeric(12,2);
  v_grand_total numeric(12,2);
  v_address_snapshot jsonb;
  v_item record;
begin
  v_profile_id := public.current_profile_id();
  if v_profile_id is null then
    raise exception 'Authentication required to checkout.';
  end if;

  select * into v_cart
  from public.carts
  where id = p_cart_id
    and profile_id = v_profile_id
    and status = 'active'
    and deleted_at is null
  for update;

  if not found then
    raise exception 'Cart not found or not active for this profile.';
  end if;

  select * into v_address
  from public.addresses
  where id = p_address_id
    and profile_id = v_profile_id
    and deleted_at is null;

  if not found then
    raise exception 'Address not found for this profile.';
  end if;

  if not exists (select 1 from public.cart_items where cart_id = p_cart_id) then
    raise exception 'Cart is empty.';
  end if;

  -- Re-price every line at current (and, if eligible, tier) prices.
  update public.cart_items set quantity = quantity where cart_id = p_cart_id;

  select coalesce(sum(unit_price_snapshot * quantity), 0)
  into v_subtotal
  from public.cart_items
  where cart_id = p_cart_id;

  v_grand_total := v_subtotal;

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
  )
  values (
    public.generate_order_number(), v_profile_id, p_address_id, v_cart.currency,
    v_subtotal, 0, 0, 0, v_grand_total,
    v_address_snapshot, v_address_snapshot, p_notes
  )
  returning id into v_order_id;

  for v_item in
    select
      ci.product_variant_id,
      ci.quantity,
      ci.unit_price_snapshot,
      ci.currency,
      pv.sku as variant_sku,
      pv.stock_quantity,
      pv.reserved_quantity,
      pv.is_active as variant_is_active,
      pv.deleted_at as variant_deleted_at,
      p.id as pv_product_id,
      p.title as product_title,
      p.seller_id as seller_id,
      (
        select pi.storage_path
        from public.product_images pi
        where pi.product_id = p.id and pi.is_primary = true and pi.deleted_at is null
        limit 1
      ) as image_path
    from public.cart_items ci
    join public.product_variants pv on pv.id = ci.product_variant_id
    join public.products p on p.id = pv.product_id
    where ci.cart_id = p_cart_id
  loop
    if v_item.variant_is_active is false or v_item.variant_deleted_at is not null then
      raise exception 'A product in your cart is no longer available.';
    end if;

    if v_item.stock_quantity - v_item.reserved_quantity < v_item.quantity then
      raise exception 'Insufficient stock for %.', v_item.product_title;
    end if;

    insert into public.order_items (
      order_id, product_id, product_variant_id, seller_id,
      product_title_snapshot, sku_snapshot, image_path_snapshot,
      unit_price, quantity, line_total, currency
    )
    values (
      v_order_id, v_item.pv_product_id, v_item.product_variant_id, v_item.seller_id,
      v_item.product_title, v_item.variant_sku, v_item.image_path,
      v_item.unit_price_snapshot, v_item.quantity, v_item.unit_price_snapshot * v_item.quantity, v_item.currency
    );

    update public.product_variants
    set reserved_quantity = reserved_quantity + v_item.quantity
    where id = v_item.product_variant_id;
  end loop;

  insert into public.payments (order_id, provider, method, status, amount, currency)
  values (v_order_id, 'manual', p_payment_method, 'pending', v_grand_total, v_cart.currency);

  insert into public.order_status_history (order_id, status, changed_by, notes)
  values (v_order_id, 'pending', v_profile_id, 'Order placed.');

  update public.carts
  set status = 'converted'
  where id = p_cart_id;

  return v_order_id;
end;
$function$;
