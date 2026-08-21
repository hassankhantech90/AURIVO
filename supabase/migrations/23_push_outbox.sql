-- Phase 22 / migration 23 — durable push dispatch outbox (P1, storage only).
-- Applied live as migration 23_push_outbox.
--
-- The outbox row is created in the SAME PostgreSQL transaction as the canonical
-- notifications row (committed-intent atomicity — verified: a failure after the
-- AFTER INSERT enqueue trigger rolls back both rows together). Actual network
-- delivery is asynchronous and belongs to P2 (worker + FCM). The client has no
-- access to this table; only the SECURITY DEFINER enqueue trigger and the
-- service-role worker touch it. No pg_net/pg_cron here.

create table public.push_outbox (
  id                   uuid primary key default gen_random_uuid(),
  notification_id      uuid not null references public.notifications(id) on delete cascade,
  profile_id           uuid not null references public.profiles(id) on delete cascade,
  status               text not null default 'pending'
                         check (status in ('pending','processing','sent','failed','dead')),
  attempts             int  not null default 0,
  next_attempt_at      timestamptz not null default now(),
  delivered_device_ids uuid[] not null default '{}',
  last_error           text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  processed_at         timestamptz
);
create unique index push_outbox_notification_uq on public.push_outbox (notification_id);
create index push_outbox_due on public.push_outbox (next_attempt_at) where status in ('pending','failed');

create trigger push_outbox_set_updated_at before update on public.push_outbox
  for each row execute function public.set_updated_at();

alter table public.push_outbox enable row level security;
-- No policies for authenticated/anon => full deny (client never reads/writes).
revoke all on public.push_outbox from authenticated, anon;

-- Atomic enqueue: fires within the notification's insert transaction. Skips
-- born-deleted rows; ON CONFLICT keeps enqueue idempotent (one row per
-- notification).
create or replace function public.enqueue_push_outbox()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
begin
  if NEW.deleted_at is not null then return NEW; end if;
  insert into public.push_outbox (notification_id, profile_id)
  values (NEW.id, NEW.profile_id)
  on conflict (notification_id) do nothing;
  return NEW;
end $b$;
create trigger notifications_enqueue_push after insert on public.notifications
  for each row execute function public.enqueue_push_outbox();
