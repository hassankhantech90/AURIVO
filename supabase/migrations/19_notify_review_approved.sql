-- Phase 13C / migration 19 — seller notification when a review is approved.
-- Applied live as migration 19_notify_review_approved.
--
-- Two SECURITY DEFINER AFTER UPDATE OF status triggers, one per review table,
-- firing only on the exact approval transition:
--   WHEN old.status IS DISTINCT FROM new.status
--        AND new.status = 'approved' AND new.deleted_at IS NULL
-- Approval is admin-only (enforced by the BEFORE enforce_*_review_integrity
-- triggers, which force status back to 'pending' for non-admin updates and on
-- every insert), so reviews always start 'pending' and an UPDATE trigger is
-- complete. Recipients are resolved server-side via foreign keys and differ per
-- table:
--   product_reviews -> products.seller_id -> seller_profiles.profile_id
--   seller_reviews  -> seller_profiles.profile_id
-- A persistent NOT EXISTS guard keyed on (recipient, event, review_id) makes it
-- notify-once-per-review: a later hidden/rejected -> approved transition does
-- NOT generate a second notification. Concurrency needs no advisory lock: the
-- approval is a single-row UPDATE, so PostgreSQL's row lock serializes
-- concurrent approvals of the same review, and the loser then sees the winner's
-- committed notification via NOT EXISTS.
--
-- Deep links use existing public routes (product detail / seller storefront);
-- there is no seller-studio reviews screen. Self-reviews (seller = reviewer)
-- are suppressed. RLS unchanged; notifications stays OUT of supabase_realtime.
-- Coexists with migration 15's notify_product_moderation (on products.status,
-- a different table/event). Migrations 15-18 untouched. No app change.

create or replace function public.notify_product_review_approved()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_seller uuid;
begin
  select sp.profile_id into v_seller
  from public.products pr
  join public.seller_profiles sp on sp.id = pr.seller_id and sp.deleted_at is null
  where pr.id = NEW.product_id and pr.deleted_at is null;
  if v_seller is null or v_seller = NEW.profile_id then return NEW; end if;
  insert into public.notifications(profile_id, type, title, body, data)
  select v_seller, 'seller_event', 'New product review',
         'A customer review of your product was approved.',
         jsonb_build_object('event','review_approved','review_kind','product',
           'review_id',NEW.id::text,'product_id',NEW.product_id::text,
           'route','/product/'||NEW.product_id::text)
  where not exists (select 1 from public.notifications n
                    where n.profile_id = v_seller and n.type='seller_event'
                      and n.data->>'event' = 'review_approved'
                      and n.data->>'review_id' = NEW.id::text);
  return NEW;
end $b$;

create or replace function public.notify_seller_review_approved()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_seller uuid; v_slug text;
begin
  select profile_id, slug into v_seller, v_slug
  from public.seller_profiles where id = NEW.seller_profile_id and deleted_at is null;
  if v_seller is null or v_seller = NEW.profile_id then return NEW; end if;
  insert into public.notifications(profile_id, type, title, body, data)
  select v_seller, 'seller_event', 'New store review',
         'A customer review of your store was approved.',
         jsonb_build_object('event','review_approved','review_kind','seller',
           'review_id',NEW.id::text,'seller_profile_id',NEW.seller_profile_id::text,
           'route','/seller/'||v_slug)
  where not exists (select 1 from public.notifications n
                    where n.profile_id = v_seller and n.type='seller_event'
                      and n.data->>'event' = 'review_approved'
                      and n.data->>'review_id' = NEW.id::text);
  return NEW;
end $b$;

drop trigger if exists product_reviews_notify_approved on public.product_reviews;
create trigger product_reviews_notify_approved
  after update of status on public.product_reviews
  for each row
  when (old.status is distinct from new.status and new.status = 'approved' and new.deleted_at is null)
  execute function public.notify_product_review_approved();

drop trigger if exists seller_reviews_notify_approved on public.seller_reviews;
create trigger seller_reviews_notify_approved
  after update of status on public.seller_reviews
  for each row
  when (old.status is distinct from new.status and new.status = 'approved' and new.deleted_at is null)
  execute function public.notify_seller_review_approved();
