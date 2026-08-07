create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null check (char_length(trim(full_name)) >= 2),
  email text,
  phone text,
  avatar_path text,
  status text not null default 'active' check (status in ('active', 'blocked', 'suspended')),
  is_phone_verified boolean not null default false,
  is_email_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint profiles_user_id_unique unique (user_id),
  constraint profiles_email_format_check check (
    email is null or email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
  ),
  constraint profiles_phone_format_check check (
    phone is null or phone ~ '^(\+92|0)?3[0-9]{9}$'
  )
);

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  constraint roles_name_unique unique (name),
  constraint roles_name_check check (name in ('customer', 'seller', 'business_buyer', 'support', 'finance', 'admin'))
);

create table if not exists public.profile_roles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  assigned_by uuid references public.profiles(id) on delete set null,
  constraint profile_roles_profile_id_role_id_unique unique (profile_id, role_id)
);

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  address_type text not null default 'shipping' check (address_type in ('billing', 'shipping', 'business')),
  label text,
  recipient_name text not null check (char_length(trim(recipient_name)) >= 2),
  phone text not null check (phone ~ '^(\+92|0)?3[0-9]{9}$'),
  address_line_1 text not null check (char_length(trim(address_line_1)) >= 5),
  address_line_2 text,
  area text,
  city text not null,
  province text not null check (province in ('Punjab', 'Sindh', 'Khyber Pakhtunkhwa', 'Balochistan', 'Islamabad Capital Territory', 'Gilgit-Baltistan', 'Azad Jammu and Kashmir')),
  postal_code text check (postal_code is null or postal_code ~ '^[0-9]{5}$'),
  country text not null default 'Pakistan' check (country = 'Pakistan'),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.business_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  business_name text not null check (char_length(trim(business_name)) >= 2),
  business_type text check (business_type is null or business_type in ('retailer', 'wholesaler', 'manufacturer', 'exporter', 'distributor', 'other')),
  ntn_number text check (ntn_number is null or ntn_number ~ '^[0-9]{7,8}$'),
  strn_number text check (strn_number is null or strn_number ~ '^[0-9]{13}$'),
  contact_person text not null check (char_length(trim(contact_person)) >= 2),
  contact_phone text not null check (contact_phone ~ '^(\+92|0)?3[0-9]{9}$'),
  verification_status text not null default 'pending' check (verification_status in ('pending', 'verified', 'rejected', 'suspended')),
  documents jsonb not null default '[]'::jsonb check (jsonb_typeof(documents) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint business_profiles_profile_id_unique unique (profile_id)
);

create table if not exists public.seller_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  store_name text not null check (char_length(trim(store_name)) >= 2),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description text,
  logo_url text,
  banner_url text,
  city text,
  verification_status text not null default 'pending' check (verification_status in ('pending', 'verified', 'rejected', 'suspended')),
  is_wholesale_enabled boolean not null default false,
  rating_average numeric(3,2) not null default 0 check (rating_average >= 0 and rating_average <= 5),
  rating_count integer not null default 0 check (rating_count >= 0),
  commission_rate numeric(5,2) check (commission_rate is null or (commission_rate >= 0 and commission_rate <= 100)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint seller_profiles_profile_id_unique unique (profile_id),
  constraint seller_profiles_slug_unique unique (slug)
);

comment on table public.profiles is 'Application profile for each Supabase Auth user.';
comment on column public.profiles.id is 'Primary key for the application profile.';
comment on column public.profiles.user_id is 'Supabase Auth user identifier. One auth user maps to one profile.';
comment on column public.profiles.full_name is 'Display name copied from auth metadata or defaulted during signup.';
comment on column public.profiles.email is 'User email copied from auth.users when available.';
comment on column public.profiles.phone is 'Pakistan mobile number copied from auth.users when available.';
comment on column public.profiles.avatar_path is 'Supabase Storage object path for the profile avatar, not a public URL.';
comment on column public.profiles.status is 'Operational profile status for access control and moderation.';
comment on column public.profiles.is_phone_verified is 'Indicates whether the phone has been verified.';
comment on column public.profiles.is_email_verified is 'Indicates whether the email has been verified.';
comment on column public.profiles.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.roles is 'RBAC role catalogue for application authorization.';
comment on column public.roles.id is 'Primary key for the role.';
comment on column public.roles.name is 'Unique system role name.';
comment on column public.roles.description is 'Human-readable role purpose.';

comment on table public.profile_roles is 'Join table assigning one or more RBAC roles to profiles.';
comment on column public.profile_roles.id is 'Primary key for the profile-role assignment.';
comment on column public.profile_roles.profile_id is 'Profile receiving the role assignment.';
comment on column public.profile_roles.role_id is 'Assigned role.';
comment on column public.profile_roles.assigned_at is 'Timestamp when the role was assigned.';
comment on column public.profile_roles.assigned_by is 'Profile that assigned the role, when assigned by an admin.';

comment on table public.addresses is 'Billing, shipping, and business addresses for Pakistan-first checkout and account workflows.';
comment on column public.addresses.id is 'Primary key for the address.';
comment on column public.addresses.profile_id is 'Owner profile for this address.';
comment on column public.addresses.address_type is 'Address type: billing, shipping, or business.';
comment on column public.addresses.label is 'Optional user-facing label such as Home, Office, or Warehouse.';
comment on column public.addresses.recipient_name is 'Recipient name for delivery or billing.';
comment on column public.addresses.phone is 'Pakistan mobile contact number for this address.';
comment on column public.addresses.address_line_1 is 'Primary street, building, house, or shop address.';
comment on column public.addresses.address_line_2 is 'Additional address details.';
comment on column public.addresses.area is 'Local area, sector, phase, market, or neighborhood.';
comment on column public.addresses.city is 'Pakistan city for delivery and filtering.';
comment on column public.addresses.province is 'Pakistan province or administrative territory.';
comment on column public.addresses.postal_code is 'Optional five-digit Pakistan postal code.';
comment on column public.addresses.country is 'Country fixed to Pakistan for the initial marketplace.';
comment on column public.addresses.is_default is 'Marks the default address per profile and address type.';
comment on column public.addresses.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.business_profiles is 'B2B buyer profile for wholesale access and verification.';
comment on column public.business_profiles.id is 'Primary key for the business profile.';
comment on column public.business_profiles.profile_id is 'Owner profile for this business profile.';
comment on column public.business_profiles.business_name is 'Registered or trading business name.';
comment on column public.business_profiles.business_type is 'Business classification for B2B workflows.';
comment on column public.business_profiles.ntn_number is 'Pakistan National Tax Number where applicable.';
comment on column public.business_profiles.strn_number is 'Pakistan Sales Tax Registration Number where applicable.';
comment on column public.business_profiles.contact_person is 'Primary business contact person.';
comment on column public.business_profiles.contact_phone is 'Pakistan mobile number for business contact.';
comment on column public.business_profiles.verification_status is 'Business verification lifecycle status.';
comment on column public.business_profiles.documents is 'Metadata array for verification document storage paths.';
comment on column public.business_profiles.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.seller_profiles is 'Seller storefront and marketplace verification profile.';
comment on column public.seller_profiles.id is 'Primary key for the seller profile.';
comment on column public.seller_profiles.profile_id is 'Owner profile for this seller storefront.';
comment on column public.seller_profiles.store_name is 'Public seller store name.';
comment on column public.seller_profiles.slug is 'Unique URL-safe seller storefront slug.';
comment on column public.seller_profiles.description is 'Seller storefront description.';
comment on column public.seller_profiles.logo_url is 'Seller logo URL or path reference for storefront display.';
comment on column public.seller_profiles.banner_url is 'Seller banner URL or path reference for storefront display.';
comment on column public.seller_profiles.city is 'Seller operating city in Pakistan.';
comment on column public.seller_profiles.verification_status is 'Seller verification lifecycle status.';
comment on column public.seller_profiles.is_wholesale_enabled is 'Whether the seller supports wholesale workflows.';
comment on column public.seller_profiles.rating_average is 'Cached seller rating average from seller reviews.';
comment on column public.seller_profiles.rating_count is 'Cached count of seller reviews.';
comment on column public.seller_profiles.commission_rate is 'Optional marketplace commission rate for this seller.';
comment on column public.seller_profiles.deleted_at is 'Soft delete timestamp. Null means active row.';

insert into public.roles (name, description)
values
  ('customer', 'Default buyer role for B2C marketplace access.'),
  ('seller', 'Seller role for storefront and product management.'),
  ('business_buyer', 'B2B buyer role for wholesale and RFQ access.'),
  ('support', 'Support role for customer service operations.'),
  ('finance', 'Finance role for payment and reconciliation workflows.'),
  ('admin', 'Administrator role with unrestricted management access.')
on conflict (name) do update set description = excluded.description;

create index if not exists profiles_email_idx on public.profiles (lower(email)) where email is not null and deleted_at is null;
create index if not exists profiles_phone_idx on public.profiles (phone) where phone is not null and deleted_at is null;
create index if not exists profiles_status_idx on public.profiles (status) where deleted_at is null;
create index if not exists profiles_deleted_at_idx on public.profiles (deleted_at);

create index if not exists profile_roles_profile_id_idx on public.profile_roles (profile_id);
create index if not exists profile_roles_role_id_idx on public.profile_roles (role_id);
create index if not exists profile_roles_assigned_by_idx on public.profile_roles (assigned_by);

create index if not exists addresses_profile_id_idx on public.addresses (profile_id) where deleted_at is null;
create index if not exists addresses_profile_id_address_type_idx on public.addresses (profile_id, address_type) where deleted_at is null;
create index if not exists addresses_profile_id_is_default_idx on public.addresses (profile_id, is_default) where deleted_at is null;
create index if not exists addresses_city_idx on public.addresses (city) where deleted_at is null;

create index if not exists business_profiles_verification_status_idx on public.business_profiles (verification_status) where deleted_at is null;
create index if not exists business_profiles_business_name_idx on public.business_profiles (lower(business_name)) where deleted_at is null;

create index if not exists seller_profiles_verification_status_idx on public.seller_profiles (verification_status) where deleted_at is null;
create index if not exists seller_profiles_is_wholesale_enabled_idx on public.seller_profiles (is_wholesale_enabled) where deleted_at is null;
create index if not exists seller_profiles_city_idx on public.seller_profiles (city) where city is not null and deleted_at is null;
create index if not exists seller_profiles_store_name_idx on public.seller_profiles (lower(store_name)) where deleted_at is null;

create unique index if not exists addresses_one_default_per_type_idx
  on public.addresses (profile_id, address_type)
  where is_default = true and deleted_at is null;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists addresses_set_updated_at on public.addresses;
create trigger addresses_set_updated_at
before update on public.addresses
for each row execute function public.set_updated_at();

drop trigger if exists business_profiles_set_updated_at on public.business_profiles;
create trigger business_profiles_set_updated_at
before update on public.business_profiles
for each row execute function public.set_updated_at();

drop trigger if exists seller_profiles_set_updated_at on public.seller_profiles;
create trigger seller_profiles_set_updated_at
before update on public.seller_profiles
for each row execute function public.set_updated_at();

create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id
  from public.profiles p
  where p.user_id = auth.uid()
    and p.deleted_at is null
  limit 1
$$;

create or replace function public.has_role(role_name text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles p
    join public.profile_roles pr on pr.profile_id = p.id
    join public.roles r on r.id = pr.role_id
    where p.user_id = auth.uid()
      and p.deleted_at is null
      and r.name = role_name
  )
$$;

create or replace function public.assign_customer_role(profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  customer_role_id uuid;
begin
  select r.id into customer_role_id
  from public.roles r
  where r.name = 'customer';

  if customer_role_id is not null then
    insert into public.profile_roles (profile_id, role_id)
    values (assign_customer_role.profile_id, customer_role_id)
    on conflict (profile_id, role_id) do nothing;
  end if;
end;
$$;

create or replace function public.assign_default_customer_role()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.assign_customer_role(new.id);
  return new;
end;
$$;

drop trigger if exists profiles_assign_default_customer_role on public.profiles;
create trigger profiles_assign_default_customer_role
after insert on public.profiles
for each row execute function public.assign_default_customer_role();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  created_profile_id uuid;
  profile_full_name text;
begin
  profile_full_name = nullif(trim(new.raw_user_meta_data->>'full_name'), '');

  insert into public.profiles (
    user_id,
    full_name,
    email,
    phone,
    is_email_verified,
    is_phone_verified
  )
  values (
    new.id,
    coalesce(profile_full_name, 'New User'),
    new.email,
    new.phone,
    new.email_confirmed_at is not null,
    new.phone_confirmed_at is not null
  )
  on conflict (user_id) do update set
    email = excluded.email,
    phone = excluded.phone,
    is_email_verified = excluded.is_email_verified,
    is_phone_verified = excluded.is_phone_verified
  returning id into created_profile_id;

  perform public.assign_customer_role(created_profile_id);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

revoke all on function public.current_profile_id() from public;
revoke all on function public.has_role(text) from public;
revoke all on function public.assign_customer_role(uuid) from public;
revoke all on function public.assign_default_customer_role() from public;
revoke all on function public.handle_new_user() from public;

grant execute on function public.current_profile_id() to authenticated;
grant execute on function public.has_role(text) to authenticated;

alter table public.profiles enable row level security;
alter table public.roles enable row level security;
alter table public.profile_roles enable row level security;
alter table public.addresses enable row level security;
alter table public.business_profiles enable row level security;
alter table public.seller_profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
on public.profiles
for select
to authenticated
using (user_id = auth.uid() or public.has_role('admin'));

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
on public.profiles
for insert
to authenticated
with check (user_id = auth.uid() or public.has_role('admin'));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
on public.profiles
for update
to authenticated
using (user_id = auth.uid() or public.has_role('admin'))
with check (user_id = auth.uid() or public.has_role('admin'));

drop policy if exists roles_select_authenticated on public.roles;
create policy roles_select_authenticated
on public.roles
for select
to authenticated
using (true);

drop policy if exists roles_admin_all on public.roles;
create policy roles_admin_all
on public.roles
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists profile_roles_select_own on public.profile_roles;
create policy profile_roles_select_own
on public.profile_roles
for select
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists profile_roles_admin_all on public.profile_roles;
create policy profile_roles_admin_all
on public.profile_roles
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists addresses_owner_select on public.addresses;
create policy addresses_owner_select
on public.addresses
for select
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists addresses_owner_insert on public.addresses;
create policy addresses_owner_insert
on public.addresses
for insert
to authenticated
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists addresses_owner_update on public.addresses;
create policy addresses_owner_update
on public.addresses
for update
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'))
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists addresses_owner_delete on public.addresses;
create policy addresses_owner_delete
on public.addresses
for delete
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists business_profiles_owner_select on public.business_profiles;
create policy business_profiles_owner_select
on public.business_profiles
for select
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists business_profiles_owner_insert on public.business_profiles;
create policy business_profiles_owner_insert
on public.business_profiles
for insert
to authenticated
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists business_profiles_owner_update on public.business_profiles;
create policy business_profiles_owner_update
on public.business_profiles
for update
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'))
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists business_profiles_owner_delete on public.business_profiles;
create policy business_profiles_owner_delete
on public.business_profiles
for delete
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists seller_profiles_owner_select on public.seller_profiles;
create policy seller_profiles_owner_select
on public.seller_profiles
for select
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists seller_profiles_owner_insert on public.seller_profiles;
create policy seller_profiles_owner_insert
on public.seller_profiles
for insert
to authenticated
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists seller_profiles_owner_update on public.seller_profiles;
create policy seller_profiles_owner_update
on public.seller_profiles
for update
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'))
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists seller_profiles_owner_delete on public.seller_profiles;
create policy seller_profiles_owner_delete
on public.seller_profiles
for delete
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));
