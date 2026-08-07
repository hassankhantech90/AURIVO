create table if not exists public.wishlist (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint wishlist_profile_id_product_id_unique unique (profile_id, product_id)
);

create table if not exists public.carts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete cascade,
  guest_token text,
  status text not null default 'active' check (status in ('active', 'converted', 'abandoned', 'expired')),
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  discount_total numeric(12,2) not null default 0 check (discount_total >= 0),
  grand_total numeric(12,2) not null default 0 check (grand_total >= 0),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint carts_owner_check check (profile_id is not null or guest_token is not null),
  constraint carts_guest_token_not_blank_check check (guest_token is null or char_length(trim(guest_token)) >= 16),
  constraint carts_totals_check check (grand_total >= subtotal - discount_total)
);

create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.carts(id) on delete cascade,
  product_variant_id uuid not null references public.product_variants(id) on delete restrict,
  quantity integer not null check (quantity >= 1),
  unit_price_snapshot numeric(12,2) not null check (unit_price_snapshot >= 0),
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cart_items_cart_id_product_variant_id_unique unique (cart_id, product_variant_id)
);

comment on table public.wishlist is 'Products saved by users for later purchase.';
comment on column public.wishlist.id is 'Primary key for the wishlist row.';
comment on column public.wishlist.profile_id is 'Owner profile for the wishlist item.';
comment on column public.wishlist.product_id is 'Product saved to the wishlist.';
comment on column public.wishlist.created_at is 'Timestamp when the product was added to the wishlist.';

comment on table public.carts is 'Shopping carts for authenticated profiles and guest sessions.';
comment on column public.carts.id is 'Primary key for the cart.';
comment on column public.carts.profile_id is 'Authenticated profile that owns the cart. Nullable for guest carts.';
comment on column public.carts.guest_token is 'Guest cart token used before login and during cart merge.';
comment on column public.carts.status is 'Cart lifecycle status: active, converted, abandoned, or expired.';
comment on column public.carts.currency is 'Currency used for cart totals.';
comment on column public.carts.subtotal is 'Sum of cart item price snapshots before discounts.';
comment on column public.carts.discount_total is 'Discount amount applied to the cart.';
comment on column public.carts.grand_total is 'Final cart total after discounts.';
comment on column public.carts.expires_at is 'Optional expiration timestamp for guest or inactive carts.';
comment on column public.carts.created_at is 'Timestamp when the cart was created.';
comment on column public.carts.updated_at is 'Timestamp when the cart was last updated.';
comment on column public.carts.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.cart_items is 'Line items inside a cart with immutable checkout price snapshots.';
comment on column public.cart_items.id is 'Primary key for the cart item.';
comment on column public.cart_items.cart_id is 'Cart that owns this item.';
comment on column public.cart_items.product_variant_id is 'Product variant added to the cart.';
comment on column public.cart_items.quantity is 'Quantity of the selected variant. Must be at least one.';
comment on column public.cart_items.unit_price_snapshot is 'Price captured when the item was added. This value should not be recalculated from live product pricing.';
comment on column public.cart_items.currency is 'Currency captured with the unit price snapshot.';
comment on column public.cart_items.created_at is 'Timestamp when the item was added to the cart.';
comment on column public.cart_items.updated_at is 'Timestamp when the cart item was last updated.';

create index if not exists wishlist_profile_id_idx on public.wishlist (profile_id);
create index if not exists wishlist_product_id_idx on public.wishlist (product_id);

create index if not exists carts_profile_id_idx on public.carts (profile_id) where profile_id is not null and deleted_at is null;
create index if not exists carts_guest_token_idx on public.carts (guest_token) where guest_token is not null and deleted_at is null;
create index if not exists carts_status_idx on public.carts (status) where deleted_at is null;
create index if not exists carts_profile_id_status_idx on public.carts (profile_id, status) where profile_id is not null and deleted_at is null;
create index if not exists carts_guest_token_status_idx on public.carts (guest_token, status) where guest_token is not null and deleted_at is null;
create index if not exists carts_expires_at_idx on public.carts (expires_at) where expires_at is not null and deleted_at is null;

create index if not exists cart_items_cart_id_idx on public.cart_items (cart_id);
create index if not exists cart_items_product_variant_id_idx on public.cart_items (product_variant_id);

create unique index if not exists carts_one_active_profile_cart_idx
  on public.carts (profile_id)
  where profile_id is not null and status = 'active' and deleted_at is null;

create unique index if not exists carts_one_active_guest_cart_idx
  on public.carts (guest_token)
  where guest_token is not null and status = 'active' and deleted_at is null;

drop trigger if exists carts_set_updated_at on public.carts;
create trigger carts_set_updated_at
before update on public.carts
for each row execute function public.set_updated_at();

drop trigger if exists cart_items_set_updated_at on public.cart_items;
create trigger cart_items_set_updated_at
before update on public.cart_items
for each row execute function public.set_updated_at();

alter table public.wishlist enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;

drop policy if exists wishlist_owner_select on public.wishlist;
create policy wishlist_owner_select
on public.wishlist
for select
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists wishlist_owner_insert on public.wishlist;
create policy wishlist_owner_insert
on public.wishlist
for insert
to authenticated
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists wishlist_owner_update on public.wishlist;
create policy wishlist_owner_update
on public.wishlist
for update
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'))
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists wishlist_owner_delete on public.wishlist;
create policy wishlist_owner_delete
on public.wishlist
for delete
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists carts_owner_select on public.carts;
create policy carts_owner_select
on public.carts
for select
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists carts_owner_insert on public.carts;
create policy carts_owner_insert
on public.carts
for insert
to authenticated
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists carts_owner_update on public.carts;
create policy carts_owner_update
on public.carts
for update
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'))
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists carts_owner_delete on public.carts;
create policy carts_owner_delete
on public.carts
for delete
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists carts_guest_select on public.carts;
create policy carts_guest_select
on public.carts
for select
to anon, authenticated
using (profile_id is null and guest_token is not null and deleted_at is null);

drop policy if exists carts_guest_insert on public.carts;
create policy carts_guest_insert
on public.carts
for insert
to anon, authenticated
with check (profile_id is null and guest_token is not null);

drop policy if exists carts_guest_update on public.carts;
create policy carts_guest_update
on public.carts
for update
to anon, authenticated
using (profile_id is null and guest_token is not null and deleted_at is null)
with check (profile_id is null and guest_token is not null);

drop policy if exists carts_guest_delete on public.carts;
create policy carts_guest_delete
on public.carts
for delete
to anon, authenticated
using (profile_id is null and guest_token is not null and deleted_at is null);

drop policy if exists cart_items_owner_select on public.cart_items;
create policy cart_items_owner_select
on public.cart_items
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.profile_id = public.current_profile_id()
      and c.deleted_at is null
  )
);

drop policy if exists cart_items_owner_insert on public.cart_items;
create policy cart_items_owner_insert
on public.cart_items
for insert
to authenticated
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.carts c
    where c.id = cart_id
      and c.profile_id = public.current_profile_id()
      and c.deleted_at is null
  )
);

drop policy if exists cart_items_owner_update on public.cart_items;
create policy cart_items_owner_update
on public.cart_items
for update
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.profile_id = public.current_profile_id()
      and c.deleted_at is null
  )
)
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.carts c
    where c.id = cart_id
      and c.profile_id = public.current_profile_id()
      and c.deleted_at is null
  )
);

drop policy if exists cart_items_owner_delete on public.cart_items;
create policy cart_items_owner_delete
on public.cart_items
for delete
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.profile_id = public.current_profile_id()
      and c.deleted_at is null
  )
);

drop policy if exists cart_items_guest_select on public.cart_items;
create policy cart_items_guest_select
on public.cart_items
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.profile_id is null
      and c.guest_token is not null
      and c.deleted_at is null
  )
);

drop policy if exists cart_items_guest_insert on public.cart_items;
create policy cart_items_guest_insert
on public.cart_items
for insert
to anon, authenticated
with check (
  exists (
    select 1
    from public.carts c
    where c.id = cart_id
      and c.profile_id is null
      and c.guest_token is not null
      and c.deleted_at is null
  )
);

drop policy if exists cart_items_guest_update on public.cart_items;
create policy cart_items_guest_update
on public.cart_items
for update
to anon, authenticated
using (
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.profile_id is null
      and c.guest_token is not null
      and c.deleted_at is null
  )
)
with check (
  exists (
    select 1
    from public.carts c
    where c.id = cart_id
      and c.profile_id is null
      and c.guest_token is not null
      and c.deleted_at is null
  )
);

drop policy if exists cart_items_guest_delete on public.cart_items;
create policy cart_items_guest_delete
on public.cart_items
for delete
to anon, authenticated
using (
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.profile_id is null
      and c.guest_token is not null
      and c.deleted_at is null
  )
);
