create table if not exists public.brands (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) >= 2),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  logo_path text,
  description text,
  status text not null default 'active' check (status in ('active', 'hidden', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint brands_slug_unique unique (slug)
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id) on delete set null,
  name text not null check (char_length(trim(name)) >= 2),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  image_path text,
  description text,
  sort_order integer not null default 0 check (sort_order >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint categories_slug_unique unique (slug),
  constraint categories_not_own_parent_check check (parent_id is null or parent_id <> id)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.seller_profiles(id) on delete cascade,
  brand_id uuid references public.brands(id) on delete set null,
  title text not null check (char_length(trim(title)) >= 2),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description text,
  short_description text,
  jewellery_type text not null,
  material text,
  purity text,
  gender text check (gender is null or gender in ('men', 'women', 'unisex', 'kids')),
  occasion text,
  status text not null default 'draft' check (status in ('draft', 'pending', 'approved', 'rejected', 'archived')),
  featured boolean not null default false,
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  base_price numeric(12,2) not null check (base_price >= 0),
  compare_price numeric(12,2),
  min_order_quantity integer check (min_order_quantity is null or min_order_quantity >= 1),
  rating_average numeric(3,2) not null default 0 check (rating_average >= 0 and rating_average <= 5),
  rating_count integer not null default 0 check (rating_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint products_slug_unique unique (slug),
  constraint products_compare_price_check check (compare_price is null or compare_price >= base_price)
);

create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint product_categories_product_id_category_id_unique unique (product_id, category_id)
);

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  storage_path text not null,
  image_type text not null default 'gallery' check (image_type in ('gallery', 'thumbnail', 'certificate', 'video_thumbnail')),
  alt_text text,
  sort_order integer not null default 0 check (sort_order >= 0),
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint product_images_storage_path_unique unique (storage_path)
);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  sku text not null,
  barcode text,
  weight_grams numeric(10,3) check (weight_grams is null or weight_grams >= 0),
  price numeric(12,2) not null check (price >= 0),
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  compare_price numeric(12,2),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  reserved_quantity integer not null default 0 check (reserved_quantity >= 0),
  low_stock_threshold integer not null default 0 check (low_stock_threshold >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint product_variants_sku_unique unique (sku),
  constraint product_variants_barcode_unique unique (barcode),
  constraint product_variants_compare_price_check check (compare_price is null or compare_price >= price),
  constraint product_variants_reserved_le_stock_check check (reserved_quantity <= stock_quantity)
);

create table if not exists public.attributes (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) >= 2),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  data_type text not null default 'text' check (data_type in ('text', 'number', 'boolean', 'date')),
  unit text,
  is_filterable boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint attributes_slug_unique unique (slug)
);

create table if not exists public.attribute_values (
  id uuid primary key default gen_random_uuid(),
  attribute_id uuid not null references public.attributes(id) on delete cascade,
  value text not null check (char_length(trim(value)) >= 1),
  normalized_value text,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint attribute_values_attribute_id_value_unique unique (attribute_id, value)
);

create table if not exists public.product_variant_attributes (
  id uuid primary key default gen_random_uuid(),
  product_variant_id uuid not null references public.product_variants(id) on delete cascade,
  attribute_id uuid not null references public.attributes(id) on delete cascade,
  attribute_value_id uuid references public.attribute_values(id) on delete restrict,
  custom_value text,
  created_at timestamptz not null default now(),
  constraint product_variant_attributes_variant_attribute_unique unique (product_variant_id, attribute_id),
  constraint product_variant_attributes_value_check check (attribute_value_id is not null or custom_value is not null)
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  product_variant_id uuid not null references public.product_variants(id) on delete cascade,
  movement_type text not null check (movement_type in ('purchase', 'sale', 'refund', 'return', 'adjustment', 'cancellation')),
  quantity_change integer not null check (quantity_change <> 0),
  balance_after integer not null,
  reason_code text not null check (reason_code in ('purchase', 'sale', 'refund', 'return', 'adjustment', 'damaged', 'restock', 'cancellation', 'transfer')),
  notes text,
  reference_type text,
  reference_id uuid,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.brands is 'Jewellery brands used to classify products.';
comment on column public.brands.id is 'Primary key for the brand.';
comment on column public.brands.name is 'Human-readable brand name.';
comment on column public.brands.slug is 'Unique URL-safe brand slug.';
comment on column public.brands.logo_path is 'Supabase Storage object path for the brand logo.';
comment on column public.brands.description is 'Optional brand description.';
comment on column public.brands.status is 'Brand visibility lifecycle: active, hidden, or archived.';
comment on column public.brands.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.categories is 'Hierarchical catalogue categories with unlimited nesting through parent_id.';
comment on column public.categories.id is 'Primary key for the category.';
comment on column public.categories.parent_id is 'Optional parent category for nested taxonomy.';
comment on column public.categories.name is 'Human-readable category name.';
comment on column public.categories.slug is 'Unique URL-safe category slug.';
comment on column public.categories.image_path is 'Supabase Storage object path for the category image.';
comment on column public.categories.description is 'Optional category description.';
comment on column public.categories.sort_order is 'Display ordering within category lists.';
comment on column public.categories.is_active is 'Whether the category is visible for catalogue use.';
comment on column public.categories.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.products is 'Seller-owned jewellery product listings with moderation status.';
comment on column public.products.id is 'Primary key for the product.';
comment on column public.products.seller_id is 'Seller profile that owns this product.';
comment on column public.products.brand_id is 'Optional brand associated with this product.';
comment on column public.products.title is 'Product display title.';
comment on column public.products.slug is 'Unique URL-safe product slug.';
comment on column public.products.description is 'Full product description.';
comment on column public.products.short_description is 'Short product summary for cards and previews.';
comment on column public.products.jewellery_type is 'Jewellery type such as ring, necklace, bangle, set, or earrings.';
comment on column public.products.material is 'Primary material, such as gold, silver, or artificial.';
comment on column public.products.purity is 'Jewellery purity value, such as 18K, 21K, 22K, or 925.';
comment on column public.products.gender is 'Target gender segment where applicable.';
comment on column public.products.occasion is 'Occasion or collection tag for merchandising.';
comment on column public.products.status is 'Moderation lifecycle: draft, pending, approved, rejected, or archived.';
comment on column public.products.featured is 'Whether the product is featured by marketplace merchandising.';
comment on column public.products.currency is 'Currency used for listed prices.';
comment on column public.products.base_price is 'Base product price before variant overrides.';
comment on column public.products.compare_price is 'Optional compare-at price for markdown display.';
comment on column public.products.min_order_quantity is 'Minimum quantity for wholesale or bulk purchase.';
comment on column public.products.rating_average is 'Cached average rating from product reviews.';
comment on column public.products.rating_count is 'Cached count of product reviews.';
comment on column public.products.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.product_categories is 'Join table assigning products to one or more categories.';
comment on column public.product_categories.id is 'Primary key for the product-category assignment.';
comment on column public.product_categories.product_id is 'Product assigned to the category.';
comment on column public.product_categories.category_id is 'Category assigned to the product.';

comment on table public.product_images is 'Product gallery images stored as Supabase Storage paths.';
comment on column public.product_images.id is 'Primary key for the product image.';
comment on column public.product_images.product_id is 'Product that owns this image.';
comment on column public.product_images.storage_path is 'Supabase Storage object path, not a public URL.';
comment on column public.product_images.image_type is 'Image purpose: gallery, thumbnail, certificate, or video thumbnail.';
comment on column public.product_images.alt_text is 'Accessible alternative text for the image.';
comment on column public.product_images.sort_order is 'Display ordering inside the product gallery.';
comment on column public.product_images.is_primary is 'Marks the primary image for product cards and previews.';
comment on column public.product_images.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.product_variants is 'SKU-level sellable product variants.';
comment on column public.product_variants.id is 'Primary key for the product variant.';
comment on column public.product_variants.product_id is 'Product that owns this variant.';
comment on column public.product_variants.sku is 'Unique stock keeping unit.';
comment on column public.product_variants.barcode is 'Optional unique barcode for scanning and fulfilment.';
comment on column public.product_variants.weight_grams is 'Variant weight in grams.';
comment on column public.product_variants.price is 'Variant selling price.';
comment on column public.product_variants.currency is 'Variant currency, defaulting to PKR and aligned with product currency options.';
comment on column public.product_variants.compare_price is 'Optional variant compare-at price.';
comment on column public.product_variants.stock_quantity is 'Cached inventory quantity. Inventory movements remain the audit source of truth.';
comment on column public.product_variants.reserved_quantity is 'Quantity reserved for future checkout flows to prevent overselling.';
comment on column public.product_variants.low_stock_threshold is 'Threshold for low stock alerts.';
comment on column public.product_variants.is_active is 'Whether this variant can currently be sold.';
comment on column public.product_variants.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.attributes is 'Normalized product attribute definitions such as material, purity, size, color, finish, or stone.';
comment on column public.attributes.id is 'Primary key for the attribute.';
comment on column public.attributes.name is 'Human-readable attribute name.';
comment on column public.attributes.slug is 'Unique URL-safe attribute slug.';
comment on column public.attributes.data_type is 'Expected data type for custom values.';
comment on column public.attributes.unit is 'Optional unit, such as grams, mm, or karat.';
comment on column public.attributes.is_filterable is 'Whether the attribute should be available as a catalogue filter.';
comment on column public.attributes.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.attribute_values is 'Reusable values for normalized product attributes.';
comment on column public.attribute_values.id is 'Primary key for the attribute value.';
comment on column public.attribute_values.attribute_id is 'Attribute that owns this value.';
comment on column public.attribute_values.value is 'Display value.';
comment on column public.attribute_values.normalized_value is 'Optional normalized value for search and comparison.';
comment on column public.attribute_values.sort_order is 'Display ordering for values.';
comment on column public.attribute_values.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.product_variant_attributes is 'Join table assigning normalized attributes and values to product variants.';
comment on column public.product_variant_attributes.id is 'Primary key for the variant attribute assignment.';
comment on column public.product_variant_attributes.product_variant_id is 'Variant receiving the attribute.';
comment on column public.product_variant_attributes.attribute_id is 'Attribute assigned to the variant.';
comment on column public.product_variant_attributes.attribute_value_id is 'Reusable attribute value assigned to the variant.';
comment on column public.product_variant_attributes.custom_value is 'Custom seller-provided value when no reusable value exists.';

comment on table public.inventory_movements is 'Immutable inventory movement ledger for product variants.';
comment on column public.inventory_movements.id is 'Primary key for the inventory movement.';
comment on column public.inventory_movements.product_variant_id is 'Variant whose inventory changed.';
comment on column public.inventory_movements.movement_type is 'Movement type: purchase, sale, refund, return, adjustment, or cancellation.';
comment on column public.inventory_movements.quantity_change is 'Signed quantity delta for this movement.';
comment on column public.inventory_movements.balance_after is 'Inventory balance immediately after applying this movement.';
comment on column public.inventory_movements.reason_code is 'Standardized reason code for inventory movement classification.';
comment on column public.inventory_movements.notes is 'Optional human-readable notes for the inventory movement.';
comment on column public.inventory_movements.reference_type is 'Optional external or internal reference type, such as order_item or manual_adjustment.';
comment on column public.inventory_movements.reference_id is 'Optional UUID reference for the movement source.';
comment on column public.inventory_movements.created_by is 'Profile that created the movement, when user-initiated.';

create index if not exists brands_name_idx on public.brands (lower(name)) where deleted_at is null;
create index if not exists brands_status_idx on public.brands (status) where deleted_at is null;

create index if not exists categories_parent_id_idx on public.categories (parent_id) where deleted_at is null;
create index if not exists categories_sort_order_idx on public.categories (sort_order) where deleted_at is null;
create index if not exists categories_is_active_idx on public.categories (is_active) where deleted_at is null;

create index if not exists products_seller_id_idx on public.products (seller_id) where deleted_at is null;
create index if not exists products_brand_id_idx on public.products (brand_id) where brand_id is not null and deleted_at is null;
create index if not exists products_title_idx on public.products (lower(title)) where deleted_at is null;
create index if not exists products_status_idx on public.products (status) where deleted_at is null;
create index if not exists products_featured_idx on public.products (featured) where deleted_at is null;
create index if not exists products_base_price_idx on public.products (base_price) where deleted_at is null;
create index if not exists products_status_featured_base_price_idx on public.products (status, featured, base_price) where deleted_at is null;
create index if not exists products_material_purity_idx on public.products (material, purity) where deleted_at is null;
create index if not exists products_created_at_idx on public.products (created_at desc) where deleted_at is null;
create index if not exists products_approved_idx on public.products (status, featured, created_at desc) where status = 'approved' and deleted_at is null;

create index if not exists product_categories_product_id_idx on public.product_categories (product_id);
create index if not exists product_categories_category_id_idx on public.product_categories (category_id);

create index if not exists product_images_product_id_idx on public.product_images (product_id) where deleted_at is null;
create index if not exists product_images_product_id_sort_order_idx on public.product_images (product_id, sort_order) where deleted_at is null;
create unique index if not exists product_images_one_primary_per_product_idx
  on public.product_images (product_id)
  where is_primary = true and deleted_at is null;

create unique index if not exists product_images_product_id_sort_order_unique_idx
  on public.product_images (product_id, sort_order)
  where deleted_at is null;

create index if not exists product_variants_product_id_idx on public.product_variants (product_id) where deleted_at is null;
create index if not exists product_variants_is_active_idx on public.product_variants (is_active) where deleted_at is null;
create index if not exists product_variants_stock_quantity_idx on public.product_variants (stock_quantity) where deleted_at is null;
create index if not exists product_variants_reserved_quantity_idx on public.product_variants (reserved_quantity) where deleted_at is null;

create index if not exists attributes_is_filterable_idx on public.attributes (is_filterable) where deleted_at is null;
create index if not exists attribute_values_attribute_id_idx on public.attribute_values (attribute_id) where deleted_at is null;
create index if not exists attribute_values_normalized_value_idx on public.attribute_values (normalized_value) where normalized_value is not null and deleted_at is null;

create index if not exists product_variant_attributes_variant_id_idx on public.product_variant_attributes (product_variant_id);
create index if not exists product_variant_attributes_attribute_id_idx on public.product_variant_attributes (attribute_id);
create index if not exists product_variant_attributes_attribute_value_id_idx on public.product_variant_attributes (attribute_value_id) where attribute_value_id is not null;

create index if not exists inventory_movements_variant_created_at_idx on public.inventory_movements (product_variant_id, created_at desc);
create index if not exists inventory_movements_movement_type_idx on public.inventory_movements (movement_type);
create index if not exists inventory_movements_reference_idx on public.inventory_movements (reference_type, reference_id) where reference_type is not null and reference_id is not null;
create index if not exists inventory_movements_created_by_idx on public.inventory_movements (created_by) where created_by is not null;

drop trigger if exists brands_set_updated_at on public.brands;
create trigger brands_set_updated_at
before update on public.brands
for each row execute function public.set_updated_at();

drop trigger if exists categories_set_updated_at on public.categories;
create trigger categories_set_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

drop trigger if exists product_images_set_updated_at on public.product_images;
create trigger product_images_set_updated_at
before update on public.product_images
for each row execute function public.set_updated_at();

drop trigger if exists product_variants_set_updated_at on public.product_variants;
create trigger product_variants_set_updated_at
before update on public.product_variants
for each row execute function public.set_updated_at();

drop trigger if exists attributes_set_updated_at on public.attributes;
create trigger attributes_set_updated_at
before update on public.attributes
for each row execute function public.set_updated_at();

drop trigger if exists attribute_values_set_updated_at on public.attribute_values;
create trigger attribute_values_set_updated_at
before update on public.attribute_values
for each row execute function public.set_updated_at();

alter table public.brands enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_categories enable row level security;
alter table public.product_images enable row level security;
alter table public.product_variants enable row level security;
alter table public.attributes enable row level security;
alter table public.attribute_values enable row level security;
alter table public.product_variant_attributes enable row level security;
alter table public.inventory_movements enable row level security;

drop policy if exists brands_public_select on public.brands;
create policy brands_public_select
on public.brands
for select
to anon, authenticated
using (status = 'active' and deleted_at is null);

drop policy if exists brands_admin_all on public.brands;
create policy brands_admin_all
on public.brands
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists categories_public_select on public.categories;
create policy categories_public_select
on public.categories
for select
to anon, authenticated
using (is_active = true and deleted_at is null);

drop policy if exists categories_admin_all on public.categories;
create policy categories_admin_all
on public.categories
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists products_public_select_approved on public.products;
create policy products_public_select_approved
on public.products
for select
to anon, authenticated
using (status = 'approved' and deleted_at is null);

drop policy if exists products_seller_select_own on public.products;
create policy products_seller_select_own
on public.products
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = products.seller_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists products_seller_insert_own on public.products;
create policy products_seller_insert_own
on public.products
for insert
to authenticated
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = seller_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists products_seller_update_own on public.products;
create policy products_seller_update_own
on public.products
for update
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = products.seller_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
)
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = seller_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists products_seller_delete_own on public.products;
create policy products_seller_delete_own
on public.products
for delete
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = products.seller_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists product_categories_public_select_approved on public.product_categories;
create policy product_categories_public_select_approved
on public.product_categories
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    where p.id = product_categories.product_id
      and p.status = 'approved'
      and p.deleted_at is null
  )
);

drop policy if exists product_categories_seller_all_own on public.product_categories;
create policy product_categories_seller_all_own
on public.product_categories
for all
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.products p
    join public.seller_profiles sp on sp.id = p.seller_id
    where p.id = product_categories.product_id
      and sp.profile_id = public.current_profile_id()
      and p.deleted_at is null
      and sp.deleted_at is null
  )
)
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.products p
    join public.seller_profiles sp on sp.id = p.seller_id
    where p.id = product_id
      and sp.profile_id = public.current_profile_id()
      and p.deleted_at is null
      and sp.deleted_at is null
  )
);

drop policy if exists product_images_public_select on public.product_images;
create policy product_images_public_select
on public.product_images
for select
to anon, authenticated
using (
  deleted_at is null
  and exists (
    select 1
    from public.products p
    where p.id = product_images.product_id
      and p.status = 'approved'
      and p.deleted_at is null
  )
);

drop policy if exists product_images_seller_all_own on public.product_images;
create policy product_images_seller_all_own
on public.product_images
for all
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.products p
    join public.seller_profiles sp on sp.id = p.seller_id
    where p.id = product_images.product_id
      and sp.profile_id = public.current_profile_id()
      and p.deleted_at is null
      and sp.deleted_at is null
  )
)
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.products p
    join public.seller_profiles sp on sp.id = p.seller_id
    where p.id = product_id
      and sp.profile_id = public.current_profile_id()
      and p.deleted_at is null
      and sp.deleted_at is null
  )
);

drop policy if exists product_variants_public_select_approved on public.product_variants;
create policy product_variants_public_select_approved
on public.product_variants
for select
to anon, authenticated
using (
  is_active = true
  and deleted_at is null
  and exists (
    select 1
    from public.products p
    where p.id = product_variants.product_id
      and p.status = 'approved'
      and p.deleted_at is null
  )
);

drop policy if exists product_variants_seller_all_own on public.product_variants;
create policy product_variants_seller_all_own
on public.product_variants
for all
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.products p
    join public.seller_profiles sp on sp.id = p.seller_id
    where p.id = product_variants.product_id
      and sp.profile_id = public.current_profile_id()
      and p.deleted_at is null
      and sp.deleted_at is null
  )
)
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.products p
    join public.seller_profiles sp on sp.id = p.seller_id
    where p.id = product_id
      and sp.profile_id = public.current_profile_id()
      and p.deleted_at is null
      and sp.deleted_at is null
  )
);

drop policy if exists attributes_public_select on public.attributes;
create policy attributes_public_select
on public.attributes
for select
to anon, authenticated
using (deleted_at is null);

drop policy if exists attributes_admin_all on public.attributes;
create policy attributes_admin_all
on public.attributes
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists attribute_values_public_select on public.attribute_values;
create policy attribute_values_public_select
on public.attribute_values
for select
to anon, authenticated
using (deleted_at is null);

drop policy if exists attribute_values_admin_all on public.attribute_values;
create policy attribute_values_admin_all
on public.attribute_values
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists product_variant_attributes_public_select_approved on public.product_variant_attributes;
create policy product_variant_attributes_public_select_approved
on public.product_variant_attributes
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.product_variants pv
    join public.products p on p.id = pv.product_id
    where pv.id = product_variant_attributes.product_variant_id
      and pv.is_active = true
      and pv.deleted_at is null
      and p.status = 'approved'
      and p.deleted_at is null
  )
);

drop policy if exists product_variant_attributes_seller_all_own on public.product_variant_attributes;
create policy product_variant_attributes_seller_all_own
on public.product_variant_attributes
for all
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.product_variants pv
    join public.products p on p.id = pv.product_id
    join public.seller_profiles sp on sp.id = p.seller_id
    where pv.id = product_variant_attributes.product_variant_id
      and sp.profile_id = public.current_profile_id()
      and pv.deleted_at is null
      and p.deleted_at is null
      and sp.deleted_at is null
  )
)
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.product_variants pv
    join public.products p on p.id = pv.product_id
    join public.seller_profiles sp on sp.id = p.seller_id
    where pv.id = product_variant_id
      and sp.profile_id = public.current_profile_id()
      and pv.deleted_at is null
      and p.deleted_at is null
      and sp.deleted_at is null
  )
);

drop policy if exists inventory_movements_seller_select_own on public.inventory_movements;
create policy inventory_movements_seller_select_own
on public.inventory_movements
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.product_variants pv
    join public.products p on p.id = pv.product_id
    join public.seller_profiles sp on sp.id = p.seller_id
    where pv.id = inventory_movements.product_variant_id
      and sp.profile_id = public.current_profile_id()
      and pv.deleted_at is null
      and p.deleted_at is null
      and sp.deleted_at is null
  )
);

drop policy if exists inventory_movements_seller_insert_own on public.inventory_movements;
create policy inventory_movements_seller_insert_own
on public.inventory_movements
for insert
to authenticated
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.product_variants pv
    join public.products p on p.id = pv.product_id
    join public.seller_profiles sp on sp.id = p.seller_id
    where pv.id = product_variant_id
      and sp.profile_id = public.current_profile_id()
      and pv.deleted_at is null
      and p.deleted_at is null
      and sp.deleted_at is null
  )
);

drop policy if exists inventory_movements_admin_update_delete on public.inventory_movements;
create policy inventory_movements_admin_update_delete
on public.inventory_movements
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));


