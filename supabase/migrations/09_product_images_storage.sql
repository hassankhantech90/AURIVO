-- Phase 9: product images storage bucket + seller-scoped policies.
--
-- Public read; writes restricted to the seller who owns the product, using a
-- `{product_id}/...` path convention so an object can only be written by the
-- seller that owns that product. No public-schema table/RLS/trigger change —
-- seller CRUD on products/variants/images is already governed by the existing
-- `*_seller_all_own` RLS policies.
--
-- Idempotent: safe to re-run.

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

drop policy if exists product_images_public_read on storage.objects;
create policy product_images_public_read on storage.objects
  for select using (bucket_id = 'product-images');

drop policy if exists product_images_seller_insert on storage.objects;
create policy product_images_seller_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and exists (
      select 1
      from public.products p
      join public.seller_profiles sp on sp.id = p.seller_id
      where p.id::text = (storage.foldername(name))[1]
        and sp.profile_id = public.current_profile_id()
        and p.deleted_at is null
        and sp.deleted_at is null
    )
  );

drop policy if exists product_images_seller_update on storage.objects;
create policy product_images_seller_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'product-images'
    and exists (
      select 1
      from public.products p
      join public.seller_profiles sp on sp.id = p.seller_id
      where p.id::text = (storage.foldername(name))[1]
        and sp.profile_id = public.current_profile_id()
        and p.deleted_at is null
        and sp.deleted_at is null
    )
  )
  with check (
    bucket_id = 'product-images'
    and exists (
      select 1
      from public.products p
      join public.seller_profiles sp on sp.id = p.seller_id
      where p.id::text = (storage.foldername(name))[1]
        and sp.profile_id = public.current_profile_id()
        and p.deleted_at is null
        and sp.deleted_at is null
    )
  );

drop policy if exists product_images_seller_delete on storage.objects;
create policy product_images_seller_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'product-images'
    and exists (
      select 1
      from public.products p
      join public.seller_profiles sp on sp.id = p.seller_id
      where p.id::text = (storage.foldername(name))[1]
        and sp.profile_id = public.current_profile_id()
        and p.deleted_at is null
        and sp.deleted_at is null
    )
  );
