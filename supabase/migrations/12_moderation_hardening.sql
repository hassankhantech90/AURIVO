-- Phase 12A — Moderation hardening
-- Applied live as migration version (see supabase migration history:
-- 12_moderation_hardening).
--
-- Closes two self-elevation gaps where owner/seller UPDATE policies enforce
-- ownership but not which columns change:
--   1. A seller could set their own product's status to 'approved'/'rejected'
--      (products_seller_update_own WITH CHECK is column-blind) — and the app's
--      "publish" action did exactly this, so product moderation was cosmetic.
--   2. A seller could set their own store's verification_status
--      (seller_profiles_owner_update WITH CHECK is column-blind).
--
-- Guard triggers reserve those transitions for admins (has_role('admin')).
-- Service/definer contexts (auth.uid() is null) bypass so trusted backend
-- operations are unaffected. Admin bypass is preserved. RLS is otherwise
-- unchanged.

create or replace function public.enforce_product_status_moderation()
returns trigger
language plpgsql
as $body$
begin
  if auth.uid() is null or has_role('admin') then
    return NEW;
  end if;
  if TG_OP = 'INSERT' then
    if NEW.status in ('approved', 'rejected') then
      raise exception 'Only an administrator can approve or reject products'
        using errcode = '42501';
    end if;
  elsif TG_OP = 'UPDATE' then
    if NEW.status is distinct from OLD.status
       and NEW.status in ('approved', 'rejected') then
      raise exception 'Only an administrator can approve or reject products'
        using errcode = '42501';
    end if;
  end if;
  return NEW;
end;
$body$;

create or replace function public.enforce_seller_verification_moderation()
returns trigger
language plpgsql
as $body$
begin
  if auth.uid() is null or has_role('admin') then
    return NEW;
  end if;
  if TG_OP = 'INSERT' then
    if NEW.verification_status is distinct from 'pending' then
      raise exception 'Only an administrator can set store verification status'
        using errcode = '42501';
    end if;
  elsif TG_OP = 'UPDATE' then
    if NEW.verification_status is distinct from OLD.verification_status then
      raise exception 'Only an administrator can change store verification status'
        using errcode = '42501';
    end if;
  end if;
  return NEW;
end;
$body$;

drop trigger if exists products_moderation_guard on public.products;
create trigger products_moderation_guard
  before insert or update on public.products
  for each row execute function public.enforce_product_status_moderation();

drop trigger if exists seller_profiles_verification_guard on public.seller_profiles;
create trigger seller_profiles_verification_guard
  before insert or update on public.seller_profiles
  for each row execute function public.enforce_seller_verification_moderation();
