-- Security hardening pass.
-- The application has no trusted backend server between the Flutter client and
-- Supabase, so RLS must fully own authorization. This migration closes gaps
-- where the earlier migrations allowed the client to write trust-sensitive
-- data directly (guest cart isolation, order/payment totals and status,
-- review moderation state, coupon redemption amounts) and replaces those
-- write paths with SECURITY DEFINER functions that compute or validate the
-- values on the server.

-- ---------------------------------------------------------------------------
-- 1. Seller storefronts must be publicly readable once verified, otherwise
--    buyers can see an approved product but never the seller who sells it.
-- ---------------------------------------------------------------------------

drop policy if exists seller_profiles_public_select_verified on public.seller_profiles;
create policy seller_profiles_public_select_verified
on public.seller_profiles
for select
to anon, authenticated
using (verification_status = 'verified' and deleted_at is null);

-- ---------------------------------------------------------------------------
-- 2. Guest carts: the previous policies exposed every guest cart to any
--    caller because they only checked "profile_id is null", never that the
--    caller actually holds that cart's guest_token. Guest cart access is now
--    only possible through these functions, which take the token as an
--    explicit argument and never enumerate rows by other means.
-- ---------------------------------------------------------------------------

drop policy if exists carts_guest_select on public.carts;
drop policy if exists carts_guest_insert on public.carts;
drop policy if exists carts_guest_update on public.carts;
drop policy if exists carts_guest_delete on public.carts;
drop policy if exists cart_items_guest_select on public.cart_items;
drop policy if exists cart_items_guest_insert on public.cart_items;
drop policy if exists cart_items_guest_update on public.cart_items;
drop policy if exists cart_items_guest_delete on public.cart_items;

create or replace function public.guest_cart_get_or_create(p_guest_token text)
returns public.carts
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cart public.carts;
begin
  if p_guest_token is null or char_length(trim(p_guest_token)) < 16 then
    raise exception 'A valid guest token is required.';
  end if;

  select * into v_cart
  from public.carts
  where guest_token = p_guest_token
    and profile_id is null
    and status = 'active'
    and deleted_at is null;

  if not found then
    insert into public.carts (guest_token, status)
    values (p_guest_token, 'active')
    returning * into v_cart;
  end if;

  return v_cart;
end;
$$;

create or replace function public.guest_cart_items(p_guest_token text)
returns setof public.cart_items
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return query
  select ci.*
  from public.cart_items ci
  join public.carts c on c.id = ci.cart_id
  where c.guest_token = p_guest_token
    and c.profile_id is null
    and c.deleted_at is null;
end;
$$;

create or replace function public.guest_cart_set_item(
  p_guest_token text,
  p_product_variant_id uuid,
  p_quantity integer
)
returns public.cart_items
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cart public.carts;
  v_variant public.product_variants;
  v_item public.cart_items;
begin
  v_cart := public.guest_cart_get_or_create(p_guest_token);

  select * into v_variant
  from public.product_variants
  where id = p_product_variant_id
    and is_active = true
    and deleted_at is null;

  if not found then
    raise exception 'Product variant is not available.';
  end if;

  if p_quantity <= 0 then
    delete from public.cart_items
    where cart_id = v_cart.id
      and product_variant_id = p_product_variant_id;
    return null;
  end if;

  insert into public.cart_items (cart_id, product_variant_id, quantity, unit_price_snapshot, currency)
  values (v_cart.id, p_product_variant_id, p_quantity, v_variant.price, v_variant.currency)
  on conflict (cart_id, product_variant_id) do update
  set quantity = excluded.quantity,
      unit_price_snapshot = excluded.unit_price_snapshot,
      currency = excluded.currency
  returning * into v_item;

  return v_item;
end;
$$;

create or replace function public.guest_cart_remove_item(p_guest_token text, p_cart_item_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.cart_items ci
  using public.carts c
  where ci.id = p_cart_item_id
    and ci.cart_id = c.id
    and c.guest_token = p_guest_token
    and c.profile_id is null;
end;
$$;

revoke all on function public.guest_cart_get_or_create(text) from public;
revoke all on function public.guest_cart_items(text) from public;
revoke all on function public.guest_cart_set_item(text, uuid, integer) from public;
revoke all on function public.guest_cart_remove_item(text, uuid) from public;

grant execute on function public.guest_cart_get_or_create(text) to anon, authenticated;
grant execute on function public.guest_cart_items(text) to anon, authenticated;
grant execute on function public.guest_cart_set_item(text, uuid, integer) to anon, authenticated;
grant execute on function public.guest_cart_remove_item(text, uuid) to anon, authenticated;

comment on function public.guest_cart_get_or_create(text) is 'Gets or creates the active guest cart for a token. Only entry point for guest cart access since RLS cannot scope anonymous rows to a caller.';
comment on function public.guest_cart_items(text) is 'Returns line items for the guest cart matching the given token.';
comment on function public.guest_cart_set_item(text, uuid, integer) is 'Adds, updates, or removes (quantity <= 0) a guest cart line item using server-priced product_variants data.';
comment on function public.guest_cart_remove_item(text, uuid) is 'Removes a single guest cart line item by id, scoped to the given token.';

-- Cart totals were never recomputed anywhere; keep carts.subtotal/grand_total
-- in sync with cart_items for both guest and authenticated carts.
create or replace function public.recalculate_cart_totals()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cart_id uuid;
  v_subtotal numeric(12,2);
begin
  v_cart_id := coalesce(new.cart_id, old.cart_id);

  select coalesce(sum(unit_price_snapshot * quantity), 0)
  into v_subtotal
  from public.cart_items
  where cart_id = v_cart_id;

  update public.carts
  set subtotal = v_subtotal,
      grand_total = greatest(v_subtotal - discount_total, 0)
  where id = v_cart_id;

  return null;
end;
$$;

drop trigger if exists cart_items_recalculate_totals on public.cart_items;
create trigger cart_items_recalculate_totals
after insert or update or delete on public.cart_items
for each row execute function public.recalculate_cart_totals();

-- ---------------------------------------------------------------------------
-- 3. Orders and payments: buyers could previously insert/update orders and
--    insert payments directly, including status and totals. All order and
--    payment mutation now goes through checkout_cart / cancel_order, which
--    compute totals from the cart and never accept a client-supplied status.
-- ---------------------------------------------------------------------------

drop policy if exists orders_buyer_insert on public.orders;
drop policy if exists orders_buyer_update on public.orders;
drop policy if exists payments_buyer_insert on public.payments;

drop policy if exists orders_admin_insert on public.orders;
create policy orders_admin_insert
on public.orders
for insert
to authenticated
with check (public.has_role('admin'));

drop policy if exists orders_admin_update on public.orders;
create policy orders_admin_update
on public.orders
for update
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

create sequence if not exists public.order_number_seq;

create or replace function public.generate_order_number()
returns text
language sql
set search_path = public, pg_temp
as $$
  select 'AUR' || to_char(now(), 'YYMMDD') || lpad(nextval('public.order_number_seq')::text, 6, '0');
$$;

create or replace function public.checkout_cart(
  p_cart_id uuid,
  p_address_id uuid,
  p_payment_method text default 'cash_on_delivery',
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
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
$$;

create or replace function public.cancel_order(p_order_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile_id uuid;
  v_order public.orders;
begin
  v_profile_id := public.current_profile_id();

  select * into v_order
  from public.orders
  where id = p_order_id
    and profile_id = v_profile_id
    and deleted_at is null
  for update;

  if not found then
    raise exception 'Order not found for this profile.';
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
  values (p_order_id, 'cancelled', v_profile_id, p_reason);
end;
$$;

revoke all on function public.generate_order_number() from public;
revoke all on function public.checkout_cart(uuid, uuid, text, text) from public;
revoke all on function public.cancel_order(uuid, text) from public;

grant execute on function public.checkout_cart(uuid, uuid, text, text) to authenticated;
grant execute on function public.cancel_order(uuid, text) to authenticated;

comment on function public.checkout_cart(uuid, uuid, text, text) is 'Converts an authenticated buyer''s active cart into an order, order_items, and a pending payment, computing totals and stock checks server-side.';
comment on function public.cancel_order(uuid, text) is 'Cancels a buyer''s own order while still pending/confirmed and releases reserved stock.';

-- order_status_history previously never updated orders.status, requiring two
-- separate writes; keep them in sync from a single insert, and let sellers
-- progress fulfillment (packed/shipped) for orders containing their items.
create or replace function public.sync_order_status_from_history()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.orders
  set status = new.status
  where id = new.order_id;

  return new;
end;
$$;

drop trigger if exists order_status_history_sync_order on public.order_status_history;
create trigger order_status_history_sync_order
after insert on public.order_status_history
for each row execute function public.sync_order_status_from_history();

drop policy if exists order_status_history_seller_insert on public.order_status_history;
create policy order_status_history_seller_insert
on public.order_status_history
for insert
to authenticated
with check (
  status in ('packed', 'shipped')
  and exists (
    select 1
    from public.order_items oi
    join public.seller_profiles sp on sp.id = oi.seller_id
    where oi.order_id = order_status_history.order_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists shipments_seller_manage_own on public.shipments;
create policy shipments_seller_manage_own
on public.shipments
for all
to authenticated
using (
  exists (
    select 1
    from public.order_items oi
    join public.seller_profiles sp on sp.id = oi.seller_id
    where oi.order_id = shipments.order_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
)
with check (
  exists (
    select 1
    from public.order_items oi
    join public.seller_profiles sp on sp.id = oi.seller_id
    where oi.order_id = order_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

-- ---------------------------------------------------------------------------
-- 4. Reviews: buyers could previously set status and verified_purchase
--    themselves on insert/update. Force moderation state and compute
--    verified_purchase server-side from actual delivered orders.
-- ---------------------------------------------------------------------------

create or replace function public.enforce_product_review_integrity()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.helpful_count := 0;
  elsif not public.has_role('admin') then
    new.status := 'pending';
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
$$;

drop trigger if exists product_reviews_enforce_integrity on public.product_reviews;
create trigger product_reviews_enforce_integrity
before insert or update on public.product_reviews
for each row execute function public.enforce_product_review_integrity();

create or replace function public.enforce_seller_review_integrity()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'pending';
  elsif not public.has_role('admin') then
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

  return new;
end;
$$;

drop trigger if exists seller_reviews_enforce_integrity on public.seller_reviews;
create trigger seller_reviews_enforce_integrity
before insert or update on public.seller_reviews
for each row execute function public.enforce_seller_review_integrity();

-- ---------------------------------------------------------------------------
-- 5. Coupons: buyers could previously insert coupon_redemptions with an
--    arbitrary discount_amount, and nothing enforced usage_limit or
--    per_user_limit. Redemption now only happens through redeem_coupon.
-- ---------------------------------------------------------------------------

drop policy if exists coupon_redemptions_owner_insert on public.coupon_redemptions;

create or replace function public.redeem_coupon(p_code text, p_order_id uuid)
returns public.coupon_redemptions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile_id uuid;
  v_coupon public.coupons;
  v_order public.orders;
  v_discount numeric(12,2);
  v_redemption public.coupon_redemptions;
  v_existing_count integer;
begin
  v_profile_id := public.current_profile_id();
  if v_profile_id is null then
    raise exception 'Authentication required to redeem a coupon.';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
    and profile_id = v_profile_id
    and deleted_at is null
  for update;

  if not found then
    raise exception 'Order not found for this profile.';
  end if;

  select * into v_coupon
  from public.coupons
  where upper(code) = upper(p_code)
    and status = 'active'
    and deleted_at is null
    and (starts_at is null or starts_at <= now())
    and (expires_at is null or expires_at > now())
  for update;

  if not found then
    raise exception 'Coupon is not valid.';
  end if;

  if v_coupon.usage_limit is not null and v_coupon.used_count >= v_coupon.usage_limit then
    raise exception 'Coupon usage limit reached.';
  end if;

  select count(*) into v_existing_count
  from public.coupon_redemptions
  where coupon_id = v_coupon.id
    and profile_id = v_profile_id;

  if v_existing_count >= v_coupon.per_user_limit then
    raise exception 'Coupon already used the maximum number of times.';
  end if;

  if v_order.subtotal < v_coupon.minimum_order_amount then
    raise exception 'Order does not meet the coupon minimum amount.';
  end if;

  if v_coupon.discount_type = 'percentage' then
    v_discount := round(v_order.subtotal * v_coupon.discount_value / 100, 2);
  else
    v_discount := v_coupon.discount_value;
  end if;

  if v_coupon.maximum_discount_amount is not null then
    v_discount := least(v_discount, v_coupon.maximum_discount_amount);
  end if;

  v_discount := least(v_discount, v_order.subtotal);

  insert into public.coupon_redemptions (coupon_id, profile_id, order_id, discount_amount, currency)
  values (v_coupon.id, v_profile_id, p_order_id, v_discount, v_order.currency)
  returning * into v_redemption;

  update public.coupons
  set used_count = used_count + 1
  where id = v_coupon.id;

  update public.orders
  set discount_total = v_discount,
      grand_total = subtotal + shipping_fee + tax_total - v_discount
  where id = p_order_id;

  return v_redemption;
end;
$$;

revoke all on function public.redeem_coupon(text, uuid) from public;
grant execute on function public.redeem_coupon(text, uuid) to authenticated;

comment on function public.redeem_coupon(text, uuid) is 'Validates and applies a coupon to a buyer''s own order, computing the discount server-side and enforcing usage/per-user limits.';

-- Trigger-only functions must not be reachable as PostgREST RPC endpoints.
-- Supabase grants EXECUTE to anon/authenticated by default, so revoking from
-- PUBLIC alone is not enough; revoke from the API roles explicitly. Triggers
-- still fire regardless of these grants.
revoke all on function public.recalculate_cart_totals() from public, anon, authenticated;
revoke all on function public.sync_order_status_from_history() from public, anon, authenticated;
revoke all on function public.enforce_product_review_integrity() from public, anon, authenticated;
revoke all on function public.enforce_seller_review_integrity() from public, anon, authenticated;
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.assign_customer_role(uuid) from public, anon, authenticated;
revoke all on function public.assign_default_customer_role() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
