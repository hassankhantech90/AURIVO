create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  address_id uuid references public.addresses(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'processing', 'packed', 'shipped', 'delivered', 'completed', 'cancelled', 'returned', 'refunded')),
  payment_status text not null default 'pending' check (payment_status in ('pending', 'authorized', 'paid', 'failed', 'partially_refunded', 'refunded')),
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  shipping_fee numeric(12,2) not null default 0 check (shipping_fee >= 0),
  discount_total numeric(12,2) not null default 0 check (discount_total >= 0),
  tax_total numeric(12,2) not null default 0 check (tax_total >= 0),
  grand_total numeric(12,2) not null default 0 check (grand_total >= 0),
  shipping_address_snapshot jsonb not null check (jsonb_typeof(shipping_address_snapshot) = 'object'),
  billing_address_snapshot jsonb not null check (jsonb_typeof(billing_address_snapshot) = 'object'),
  notes text,
  placed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint orders_order_number_unique unique (order_number),
  constraint orders_totals_check check (grand_total = subtotal + shipping_fee + tax_total - discount_total)
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  product_variant_id uuid not null references public.product_variants(id) on delete restrict,
  seller_id uuid not null references public.seller_profiles(id) on delete restrict,
  product_title_snapshot text not null,
  variant_title_snapshot text,
  sku_snapshot text not null,
  image_path_snapshot text,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity >= 1),
  line_total numeric(12,2) not null,
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint order_items_line_total_check check (line_total = unit_price * quantity)
);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null check (status in ('pending', 'confirmed', 'processing', 'packed', 'shipped', 'delivered', 'completed', 'cancelled', 'returned', 'refunded')),
  changed_by uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null,
  method text not null,
  status text not null default 'pending' check (status in ('pending', 'authorized', 'paid', 'failed', 'partially_refunded', 'refunded')),
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  transaction_reference text,
  provider_response jsonb not null default '{}'::jsonb check (jsonb_typeof(provider_response) = 'object'),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint payments_order_id_unique unique (order_id),
  constraint payments_transaction_reference_unique unique (transaction_reference)
);

create table if not exists public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  attempt_number integer not null check (attempt_number >= 1),
  status text not null default 'pending' check (status in ('pending', 'authorized', 'paid', 'failed', 'timeout', 'cancelled')),
  error_code text,
  error_message text,
  provider_response jsonb not null default '{}'::jsonb check (jsonb_typeof(provider_response) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payment_attempts_payment_id_attempt_number_unique unique (payment_id, attempt_number)
);

create table if not exists public.shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  courier text,
  tracking_number text,
  tracking_url text,
  status text not null default 'pending' check (status in ('pending', 'ready_to_ship', 'shipped', 'in_transit', 'out_for_delivery', 'delivered', 'failed', 'returned', 'cancelled')),
  shipped_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint shipments_tracking_number_unique unique (tracking_number)
);

create table if not exists public.tracking_events (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  status text not null,
  location text,
  description text,
  event_time timestamptz not null,
  created_at timestamptz not null default now()
);

comment on table public.orders is 'Order headers for buyer purchases, totals, status, and address snapshots.';
comment on column public.orders.id is 'Primary key for the order.';
comment on column public.orders.order_number is 'Unique human-readable order number for customer support and tracking.';
comment on column public.orders.profile_id is 'Buyer profile that placed the order.';
comment on column public.orders.address_id is 'Optional address record used when placing the order.';
comment on column public.orders.status is 'Order lifecycle status.';
comment on column public.orders.payment_status is 'Payment lifecycle status for the order.';
comment on column public.orders.currency is 'Currency used for all order totals.';
comment on column public.orders.subtotal is 'Sum of order item line totals before fees, discounts, and taxes.';
comment on column public.orders.shipping_fee is 'Shipping fee charged for the order.';
comment on column public.orders.discount_total is 'Total discount applied to the order.';
comment on column public.orders.tax_total is 'Tax amount applied to the order.';
comment on column public.orders.grand_total is 'Final payable order amount.';
comment on column public.orders.shipping_address_snapshot is 'Immutable shipping address JSON snapshot captured at checkout.';
comment on column public.orders.billing_address_snapshot is 'Immutable billing address JSON snapshot captured at checkout.';
comment on column public.orders.notes is 'Optional buyer or internal order notes.';
comment on column public.orders.placed_at is 'Timestamp when the order was placed.';
comment on column public.orders.created_at is 'Timestamp when the order row was created.';
comment on column public.orders.updated_at is 'Timestamp when the order row was last updated.';
comment on column public.orders.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.order_items is 'Immutable purchased product variant line items for orders.';
comment on column public.order_items.id is 'Primary key for the order item.';
comment on column public.order_items.order_id is 'Order that owns this line item.';
comment on column public.order_items.product_id is 'Product purchased in this line item.';
comment on column public.order_items.product_variant_id is 'SKU-level product variant purchased in this line item.';
comment on column public.order_items.seller_id is 'Seller responsible for fulfilling this line item.';
comment on column public.order_items.product_title_snapshot is 'Product title captured at purchase time.';
comment on column public.order_items.variant_title_snapshot is 'Variant title or attribute summary captured at purchase time.';
comment on column public.order_items.sku_snapshot is 'SKU captured at purchase time.';
comment on column public.order_items.image_path_snapshot is 'Primary image storage path captured at purchase time.';
comment on column public.order_items.unit_price is 'Unit price captured at purchase time.';
comment on column public.order_items.quantity is 'Purchased quantity.';
comment on column public.order_items.line_total is 'Unit price multiplied by quantity.';
comment on column public.order_items.currency is 'Currency captured for this line item.';
comment on column public.order_items.created_at is 'Timestamp when the order item row was created.';
comment on column public.order_items.updated_at is 'Timestamp when the order item row was last updated.';

comment on table public.order_status_history is 'Append-only status transition history for orders.';
comment on column public.order_status_history.id is 'Primary key for the order status history row.';
comment on column public.order_status_history.order_id is 'Order whose status changed.';
comment on column public.order_status_history.status is 'New order status recorded for this event.';
comment on column public.order_status_history.changed_by is 'Profile that changed the status, when user-initiated.';
comment on column public.order_status_history.notes is 'Optional notes explaining the status change.';
comment on column public.order_status_history.created_at is 'Timestamp when the status change was recorded.';

comment on table public.payments is 'Logical payment record for an order.';
comment on column public.payments.id is 'Primary key for the payment.';
comment on column public.payments.order_id is 'Order associated with this payment.';
comment on column public.payments.provider is 'Payment provider or gateway name.';
comment on column public.payments.method is 'Payment method, such as card, bank_transfer, wallet, or cash_on_delivery.';
comment on column public.payments.status is 'Payment lifecycle status.';
comment on column public.payments.amount is 'Payment amount.';
comment on column public.payments.currency is 'Currency for the payment amount.';
comment on column public.payments.transaction_reference is 'Unique provider transaction reference when available.';
comment on column public.payments.provider_response is 'Latest provider response payload for audit and reconciliation.';
comment on column public.payments.paid_at is 'Timestamp when payment was successfully captured or marked paid.';
comment on column public.payments.created_at is 'Timestamp when the payment row was created.';
comment on column public.payments.updated_at is 'Timestamp when the payment row was last updated.';
comment on column public.payments.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.payment_attempts is 'Individual payment gateway attempts and retry outcomes.';
comment on column public.payment_attempts.id is 'Primary key for the payment attempt.';
comment on column public.payment_attempts.payment_id is 'Payment associated with this attempt.';
comment on column public.payment_attempts.attempt_number is 'Sequential attempt number for the payment.';
comment on column public.payment_attempts.status is 'Attempt status, including failed and timeout outcomes.';
comment on column public.payment_attempts.error_code is 'Gateway or internal error code when an attempt fails.';
comment on column public.payment_attempts.error_message is 'Human-readable error message for failed attempts.';
comment on column public.payment_attempts.provider_response is 'Raw provider response payload for this attempt.';
comment on column public.payment_attempts.created_at is 'Timestamp when the payment attempt row was created.';
comment on column public.payment_attempts.updated_at is 'Timestamp when the payment attempt row was last updated.';

comment on table public.shipments is 'Shipment records for order fulfilment and courier tracking.';
comment on column public.shipments.id is 'Primary key for the shipment.';
comment on column public.shipments.order_id is 'Order being shipped.';
comment on column public.shipments.courier is 'Courier or logistics provider name.';
comment on column public.shipments.tracking_number is 'Courier tracking number when available.';
comment on column public.shipments.tracking_url is 'Courier tracking URL when available.';
comment on column public.shipments.status is 'Shipment lifecycle status.';
comment on column public.shipments.shipped_at is 'Timestamp when the shipment left the seller or warehouse.';
comment on column public.shipments.delivered_at is 'Timestamp when the shipment was delivered.';
comment on column public.shipments.created_at is 'Timestamp when the shipment row was created.';
comment on column public.shipments.updated_at is 'Timestamp when the shipment row was last updated.';
comment on column public.shipments.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.tracking_events is 'Shipment tracking timeline events.';
comment on column public.tracking_events.id is 'Primary key for the tracking event.';
comment on column public.tracking_events.shipment_id is 'Shipment associated with this tracking event.';
comment on column public.tracking_events.status is 'Tracking event status label.';
comment on column public.tracking_events.location is 'Location reported by courier for this event.';
comment on column public.tracking_events.description is 'Human-readable tracking event description.';
comment on column public.tracking_events.event_time is 'Time the tracking event occurred.';
comment on column public.tracking_events.created_at is 'Timestamp when the tracking event was stored.';

create index if not exists orders_profile_id_idx on public.orders (profile_id) where deleted_at is null;
create index if not exists orders_address_id_idx on public.orders (address_id) where address_id is not null and deleted_at is null;
create index if not exists orders_status_idx on public.orders (status) where deleted_at is null;
create index if not exists orders_payment_status_idx on public.orders (payment_status) where deleted_at is null;
create index if not exists orders_profile_status_placed_at_idx on public.orders (profile_id, status, placed_at desc) where deleted_at is null;
create index if not exists orders_placed_at_idx on public.orders (placed_at desc) where deleted_at is null;

create index if not exists order_items_order_id_idx on public.order_items (order_id);
create index if not exists order_items_product_id_idx on public.order_items (product_id);
create index if not exists order_items_product_variant_id_idx on public.order_items (product_variant_id);
create index if not exists order_items_seller_id_idx on public.order_items (seller_id);
create index if not exists order_items_seller_order_idx on public.order_items (seller_id, order_id);

create index if not exists order_status_history_order_id_created_at_idx on public.order_status_history (order_id, created_at desc);
create index if not exists order_status_history_status_idx on public.order_status_history (status);
create index if not exists order_status_history_changed_by_idx on public.order_status_history (changed_by) where changed_by is not null;

create index if not exists payments_order_id_idx on public.payments (order_id) where deleted_at is null;
create index if not exists payments_status_idx on public.payments (status) where deleted_at is null;
create index if not exists payments_provider_idx on public.payments (provider) where deleted_at is null;
create index if not exists payments_paid_at_idx on public.payments (paid_at desc) where paid_at is not null and deleted_at is null;

create index if not exists payment_attempts_payment_id_idx on public.payment_attempts (payment_id);
create index if not exists payment_attempts_status_idx on public.payment_attempts (status);
create index if not exists payment_attempts_payment_status_idx on public.payment_attempts (payment_id, status);

create index if not exists shipments_order_id_idx on public.shipments (order_id) where deleted_at is null;
create index if not exists shipments_status_idx on public.shipments (status) where deleted_at is null;
create index if not exists shipments_tracking_number_idx on public.shipments (tracking_number) where tracking_number is not null and deleted_at is null;

create index if not exists tracking_events_shipment_id_idx on public.tracking_events (shipment_id);
create index if not exists tracking_events_shipment_event_time_idx on public.tracking_events (shipment_id, event_time desc);
create index if not exists tracking_events_status_idx on public.tracking_events (status);

drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

drop trigger if exists order_items_set_updated_at on public.order_items;
create trigger order_items_set_updated_at
before update on public.order_items
for each row execute function public.set_updated_at();

drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at
before update on public.payments
for each row execute function public.set_updated_at();

drop trigger if exists payment_attempts_set_updated_at on public.payment_attempts;
create trigger payment_attempts_set_updated_at
before update on public.payment_attempts
for each row execute function public.set_updated_at();

drop trigger if exists shipments_set_updated_at on public.shipments;
create trigger shipments_set_updated_at
before update on public.shipments
for each row execute function public.set_updated_at();

alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.payments enable row level security;
alter table public.payment_attempts enable row level security;
alter table public.shipments enable row level security;
alter table public.tracking_events enable row level security;

drop policy if exists orders_buyer_select on public.orders;
create policy orders_buyer_select
on public.orders
for select
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists orders_buyer_insert on public.orders;
create policy orders_buyer_insert
on public.orders
for insert
to authenticated
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists orders_buyer_update on public.orders;
create policy orders_buyer_update
on public.orders
for update
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'))
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists orders_admin_delete on public.orders;
create policy orders_admin_delete
on public.orders
for delete
to authenticated
using (public.has_role('admin'));

drop policy if exists order_items_buyer_select on public.order_items;
create policy order_items_buyer_select
on public.order_items
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.profile_id = public.current_profile_id()
      and o.deleted_at is null
  )
);

drop policy if exists order_items_seller_select on public.order_items;
create policy order_items_seller_select
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.seller_profiles sp
    where sp.id = order_items.seller_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists order_items_admin_all on public.order_items;
create policy order_items_admin_all
on public.order_items
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists order_status_history_buyer_select on public.order_status_history;
create policy order_status_history_buyer_select
on public.order_status_history
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.orders o
    where o.id = order_status_history.order_id
      and o.profile_id = public.current_profile_id()
      and o.deleted_at is null
  )
);

drop policy if exists order_status_history_admin_insert on public.order_status_history;
create policy order_status_history_admin_insert
on public.order_status_history
for insert
to authenticated
with check (public.has_role('admin'));

drop policy if exists order_status_history_admin_update_delete on public.order_status_history;
create policy order_status_history_admin_update_delete
on public.order_status_history
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists payments_buyer_select on public.payments;
create policy payments_buyer_select
on public.payments
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.orders o
    where o.id = payments.order_id
      and o.profile_id = public.current_profile_id()
      and o.deleted_at is null
  )
);

drop policy if exists payments_buyer_insert on public.payments;
create policy payments_buyer_insert
on public.payments
for insert
to authenticated
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.orders o
    where o.id = order_id
      and o.profile_id = public.current_profile_id()
      and o.deleted_at is null
  )
);

drop policy if exists payments_admin_update_delete on public.payments;
create policy payments_admin_update_delete
on public.payments
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists payment_attempts_buyer_select on public.payment_attempts;
create policy payment_attempts_buyer_select
on public.payment_attempts
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.payments p
    join public.orders o on o.id = p.order_id
    where p.id = payment_attempts.payment_id
      and o.profile_id = public.current_profile_id()
      and p.deleted_at is null
      and o.deleted_at is null
  )
);

drop policy if exists payment_attempts_buyer_insert on public.payment_attempts;
create policy payment_attempts_buyer_insert
on public.payment_attempts
for insert
to authenticated
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.payments p
    join public.orders o on o.id = p.order_id
    where p.id = payment_id
      and o.profile_id = public.current_profile_id()
      and p.deleted_at is null
      and o.deleted_at is null
  )
);

drop policy if exists payment_attempts_admin_update_delete on public.payment_attempts;
create policy payment_attempts_admin_update_delete
on public.payment_attempts
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists shipments_buyer_select on public.shipments;
create policy shipments_buyer_select
on public.shipments
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.orders o
    where o.id = shipments.order_id
      and o.profile_id = public.current_profile_id()
      and o.deleted_at is null
  )
);

drop policy if exists shipments_admin_all on public.shipments;
create policy shipments_admin_all
on public.shipments
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists tracking_events_buyer_select on public.tracking_events;
create policy tracking_events_buyer_select
on public.tracking_events
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.shipments s
    join public.orders o on o.id = s.order_id
    where s.id = tracking_events.shipment_id
      and o.profile_id = public.current_profile_id()
      and s.deleted_at is null
      and o.deleted_at is null
  )
);

drop policy if exists tracking_events_admin_all on public.tracking_events;
create policy tracking_events_admin_all
on public.tracking_events
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));
