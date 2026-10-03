-- Migration 51 — transactional email outbox (Resend), OFF by default.
-- Applied live as migration 51_email_outbox.
--
-- Mirrors the push pipeline (migrations 23-25): every canonical notifications
-- row of an emailable type gets an email_outbox row in the SAME transaction,
-- and the email-dispatch Edge Function drains it through three SECURITY
-- DEFINER worker RPCs as the least-privilege role email_dispatch_worker (no
-- table privileges). Nothing is enqueued until an operator flips
-- email_settings.enabled = true (docs/EMAIL_SETUP.md), so applying this has no
-- behavioural effect today.
--
-- The recipient address is resolved at CLAIM time from auth.users (confirmed
-- addresses only), never stored by the client and never exposed to it.
-- chat_message is not emailed by default (too chatty); the type list is data.

-- ---------------------------------------------------------------- settings
create table public.email_settings (
  id          boolean primary key default true check (id),   -- singleton
  enabled     boolean not null default false,
  types       text[]  not null default '{order_update,seller_event,support,system}',
  updated_at  timestamptz not null default now()
);
insert into public.email_settings default values;
create trigger email_settings_set_updated_at before update on public.email_settings
  for each row execute function public.set_updated_at();
alter table public.email_settings enable row level security;
revoke all on public.email_settings from authenticated, anon;

-- ---------------------------------------------------------------- outbox
create table public.email_outbox (
  id               uuid primary key default gen_random_uuid(),
  notification_id  uuid not null references public.notifications(id) on delete cascade,
  profile_id       uuid not null references public.profiles(id) on delete cascade,
  status           text not null default 'pending'
                     check (status in ('pending','processing','failed','sent','skipped','dead')),
  terminal_reason  text check (terminal_reason is null or terminal_reason in
                     ('no_address','notification_deleted','profile_deleted','rejected','max_attempts')),
  attempts         int  not null default 0,
  next_attempt_at  timestamptz not null default now(),
  lease_expires_at timestamptz,
  claim_id         uuid,
  provider_id      text,
  last_error       text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  processed_at     timestamptz
);
create unique index email_outbox_notification_uq on public.email_outbox (notification_id);
create index email_outbox_claimable on public.email_outbox (next_attempt_at) where status in ('pending','failed');
create index email_outbox_leased    on public.email_outbox (lease_expires_at) where status = 'processing';
create trigger email_outbox_set_updated_at before update on public.email_outbox
  for each row execute function public.set_updated_at();
alter table public.email_outbox enable row level security;
revoke all on public.email_outbox from authenticated, anon;

-- Atomic, idempotent enqueue inside the notification's insert transaction.
create or replace function public.enqueue_email_outbox()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
begin
  if NEW.deleted_at is not null then return NEW; end if;
  if not exists (select 1 from public.email_settings s
                  where s.enabled and NEW.type = any(s.types)) then
    return NEW;
  end if;
  insert into public.email_outbox (notification_id, profile_id)
  values (NEW.id, NEW.profile_id)
  on conflict (notification_id) do nothing;
  return NEW;
end $b$;
revoke execute on function public.enqueue_email_outbox() from public;
create trigger notifications_enqueue_email after insert on public.notifications
  for each row execute function public.enqueue_email_outbox();

-- ---------------------------------------------------------------- worker RPCs
create or replace function public.requeue_stale_email(p_grace_seconds int default 0)
returns int language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_count int;
begin
  update public.email_outbox set
    status          = case when attempts >= 6 then 'dead' else 'failed' end,
    terminal_reason = case when attempts >= 6 then 'max_attempts' else terminal_reason end,
    processed_at    = case when attempts >= 6 then now() else processed_at end,
    next_attempt_at = now(),
    last_error      = coalesce(last_error, 'lease_expired'),
    lease_expires_at = null, claim_id = null
  where status = 'processing' and lease_expires_at is not null
    and lease_expires_at < now() - make_interval(secs => greatest(coalesce(p_grace_seconds,0),0));
  get diagnostics v_count = row_count;
  return v_count;
end $b$;

-- Claims a batch with a lease + fencing token and returns what the worker needs
-- to send: recipient, name, subject (title), text body, deep-link route, event.
create or replace function public.claim_email_outbox(p_batch int default 25, p_lease_seconds int default 120)
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare
  v_batch int := least(greatest(coalesce(p_batch,25),1),50);
  v_lease int := greatest(coalesce(p_lease_seconds,120),30);
  r record; n record; v_email text; v_name text; v_pdel timestamptz;
  v_claim uuid; v_result jsonb := '[]'::jsonb;
begin
  for r in
    select o.id, o.notification_id, o.profile_id
      from public.email_outbox o
     where o.status in ('pending','failed') and o.next_attempt_at <= now() and o.attempts < 6
     order by o.next_attempt_at
     for update skip locked
     limit v_batch
  loop
    select x.deleted_at, x.title, x.body, x.type, x.data into n
      from public.notifications x where x.id = r.notification_id;
    if n.deleted_at is not null then
      update public.email_outbox set status='skipped', terminal_reason='notification_deleted',
        processed_at=now(), lease_expires_at=null, claim_id=null where id=r.id;
      continue;
    end if;

    select p.deleted_at, p.full_name,
           case when u.email_confirmed_at is not null then u.email end
      into v_pdel, v_name, v_email
      from public.profiles p left join auth.users u on u.id = p.user_id
     where p.id = r.profile_id;
    if not found or v_pdel is not null then
      update public.email_outbox set status='skipped', terminal_reason='profile_deleted',
        processed_at=now(), lease_expires_at=null, claim_id=null where id=r.id;
      continue;
    end if;
    if v_email is null or v_email = '' then
      update public.email_outbox set status='skipped', terminal_reason='no_address',
        processed_at=now(), lease_expires_at=null, claim_id=null where id=r.id;
      continue;
    end if;

    v_claim := gen_random_uuid();
    update public.email_outbox set status='processing', attempts=attempts+1,
      lease_expires_at = now() + make_interval(secs => v_lease),
      claim_id = v_claim, terminal_reason = null
     where id=r.id;

    v_result := v_result || jsonb_build_object(
      'outbox_id', r.id, 'claim_id', v_claim, 'notification_id', r.notification_id,
      'to', v_email, 'name', v_name, 'type', n.type,
      'subject', n.title, 'body', n.body,
      'route', n.data->>'route', 'event', n.data->>'event');
  end loop;
  return v_result;
end $b$;

-- Reports one send. p_outcome: sent | rejected (permanent, e.g. invalid address)
-- | transient (retry with backoff). Fenced by status='processing' + claim_id.
create or replace function public.report_email_result(
  p_outbox_id uuid, p_claim_id uuid, p_outcome text, p_provider_id text default null)
returns boolean language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_status text; v_claim uuid; v_attempts int;
begin
  if p_outcome is null or p_outcome not in ('sent','rejected','transient') then return false; end if;
  select status, claim_id, attempts into v_status, v_claim, v_attempts
    from public.email_outbox where id = p_outbox_id for update;
  if not found or v_status <> 'processing' or v_claim is distinct from p_claim_id then
    return false;
  end if;

  if p_outcome = 'sent' then
    update public.email_outbox set status='sent', provider_id=left(p_provider_id, 200),
      processed_at=now(), lease_expires_at=null, claim_id=null, last_error=null where id=p_outbox_id;
  elsif p_outcome = 'rejected' then
    update public.email_outbox set status='dead', terminal_reason='rejected', last_error='rejected',
      processed_at=now(), lease_expires_at=null, claim_id=null where id=p_outbox_id;
  elsif v_attempts >= 6 then
    update public.email_outbox set status='dead', terminal_reason='max_attempts',
      last_error='max_attempts_transient', processed_at=now(),
      lease_expires_at=null, claim_id=null where id=p_outbox_id;
  else
    update public.email_outbox set status='failed', last_error='transient',
      lease_expires_at=null, claim_id=null,
      next_attempt_at = now() + (case v_attempts
        when 1 then interval '1 minute'  when 2 then interval '5 minutes'
        when 3 then interval '30 minutes' when 4 then interval '2 hours'
        else interval '6 hours' end) * (0.8 + random()*0.4)
      where id=p_outbox_id;
  end if;
  return true;
end $b$;

revoke all on function public.requeue_stale_email(int)                  from public, authenticated, anon;
revoke all on function public.claim_email_outbox(int,int)               from public, authenticated, anon;
revoke all on function public.report_email_result(uuid,uuid,text,text)  from public, authenticated, anon;

-- ---------------------------------------------------------------- worker role
-- LOGIN with NO password: the password is set out-of-band (ALTER ROLE in the
-- SQL editor) and stored only as the EMAIL_WORKER_DB_URL function secret.
do $r$ begin
  if not exists (select 1 from pg_roles where rolname='email_dispatch_worker') then
    create role email_dispatch_worker login noinherit nocreatedb nocreaterole nobypassrls noreplication;
  end if;
end $r$;
grant execute on function public.requeue_stale_email(int)                 to email_dispatch_worker;
grant execute on function public.claim_email_outbox(int,int)              to email_dispatch_worker;
grant execute on function public.report_email_result(uuid,uuid,text,text) to email_dispatch_worker;
