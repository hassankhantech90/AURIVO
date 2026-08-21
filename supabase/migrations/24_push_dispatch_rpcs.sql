-- Phase 22 / migration 24 — push dispatch worker RPCs + queue-state hardening (P2 DB layer).
-- Applied live as migration 24_push_dispatch_rpcs.
--
-- Design B: the Edge Function authenticates as role push_worker and may ONLY execute the
-- three worker RPCs; it has no direct DML/SELECT on push_outbox / push_devices / notifications.
-- Adds crash-recovery lease + a claim fencing token (claim_id) + the exact claimed device set
-- (claimed_device_ids) so a stalled worker cannot overwrite a newer generation, and so a report
-- is accepted only if it covers exactly the claimed devices. Extends the status vocabulary to
-- distinguish sent / skipped / dead with a machine-readable terminal_reason.
-- No pg_net/pg_cron/Edge Function/secrets here (those are later P2 steps, gated on P0 ops).

alter table public.push_outbox add column lease_expires_at timestamptz;
alter table public.push_outbox add column claim_id uuid;
alter table public.push_outbox add column terminal_reason text;
alter table public.push_outbox add column claimed_device_ids uuid[];

alter table public.push_outbox drop constraint push_outbox_status_check;
alter table public.push_outbox add constraint push_outbox_status_check
  check (status in ('pending','processing','failed','sent','skipped','dead'));
alter table public.push_outbox add constraint push_outbox_terminal_reason_check
  check (terminal_reason is null or terminal_reason in
    ('no_eligible_device','notification_deleted','profile_deleted','max_attempts'));

create index push_outbox_claimable on public.push_outbox (next_attempt_at) where status in ('pending','failed');
create index push_outbox_leased    on public.push_outbox (lease_expires_at) where status = 'processing';

-- least-privilege worker role (authenticated via a signed JWT carrying role=push_worker)
do $r$ begin
  if not exists (select 1 from pg_roles where rolname='push_worker') then create role push_worker nologin; end if;
end $r$;
grant push_worker to authenticator;   -- lets PostgREST SET ROLE from the JWT role claim

-- crash recovery: reclaim expired-lease processing rows (run first each drain cycle)
create or replace function public.requeue_stale_push(p_grace_seconds int default 0)
returns int language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_count int;
begin
  update public.push_outbox set
    status          = case when attempts >= 8 then 'dead' else 'failed' end,
    terminal_reason = case when attempts >= 8 then 'max_attempts' else terminal_reason end,
    next_attempt_at = case when attempts >= 8 then next_attempt_at else now() end,
    processed_at    = case when attempts >= 8 then now() else processed_at end,
    last_error      = coalesce(last_error, 'lease_expired'),
    lease_expires_at = null, claim_id = null, claimed_device_ids = null
  where status='processing' and lease_expires_at is not null
    and lease_expires_at < now() - make_interval(secs => greatest(coalesce(p_grace_seconds,0),0));
  get diagnostics v_count = row_count;
  return v_count;
end $b$;

-- claim a batch: lease + fencing token + exact claimed device set; resolve eligibility;
-- close ineligible rows as skipped with a terminal_reason (never counted as delivery).
create or replace function public.claim_push_outbox(p_batch int default 50, p_lease_seconds int default 120)
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare
  v_batch int := least(greatest(coalesce(p_batch,50),1),50);
  v_lease int := greatest(coalesce(p_lease_seconds,120),30);
  r record; v_result jsonb := '[]'::jsonb; v_claim uuid;
  v_ndel timestamptz; v_title text; v_body text; v_data jsonb; v_ok boolean; v_devices jsonb; v_ids uuid[];
begin
  for r in
    select o.id, o.notification_id, o.profile_id, o.delivered_device_ids
      from public.push_outbox o
     where o.status in ('pending','failed') and o.next_attempt_at <= now() and o.attempts < 8
     order by o.next_attempt_at
     for update skip locked
     limit v_batch
  loop
    select n.deleted_at, n.title, n.body, n.data into v_ndel, v_title, v_body, v_data
      from public.notifications n where n.id = r.notification_id;
    if v_ndel is not null then
      update public.push_outbox set status='skipped', terminal_reason='notification_deleted',
        processed_at=now(), lease_expires_at=null, claim_id=null, claimed_device_ids=null where id=r.id;
      continue;
    end if;

    select exists(select 1 from public.profiles p where p.id=r.profile_id and p.deleted_at is null) into v_ok;
    if not v_ok then
      update public.push_outbox set status='skipped', terminal_reason='profile_deleted',
        processed_at=now(), lease_expires_at=null, claim_id=null, claimed_device_ids=null where id=r.id;
      continue;
    end if;

    select jsonb_agg(jsonb_build_object('device_id', d.id, 'token', d.push_token, 'platform', d.platform)),
           array_agg(d.id)
      into v_devices, v_ids
      from public.push_devices d
     where d.profile_id = r.profile_id and d.deleted_at is null and d.enabled = true
       and d.permission_status in ('granted','provisional')
       and not (d.id = any(r.delivered_device_ids));
    if v_devices is null then
      update public.push_outbox set status='skipped', terminal_reason='no_eligible_device',
        processed_at=now(), lease_expires_at=null, claim_id=null, claimed_device_ids=null where id=r.id;
      continue;
    end if;

    v_claim := gen_random_uuid();
    update public.push_outbox set status='processing', attempts=attempts+1,
      lease_expires_at = now() + make_interval(secs => v_lease),
      claim_id = v_claim, claimed_device_ids = v_ids, terminal_reason = null
     where id=r.id;

    v_result := v_result || jsonb_build_object(
      'outbox_id', r.id, 'claim_id', v_claim, 'notification_id', r.notification_id,
      'title', v_title, 'body', v_body,
      'data', jsonb_build_object('notification_id', r.notification_id::text,
                                 'route', v_data->>'route', 'event', v_data->>'event'),
      'devices', v_devices);
  end loop;
  return v_result;
end $b$;

-- report results — fully validated before any mutation. Fenced by
-- (status='processing' AND claim_id matches); results must be a non-empty JSON array of
-- {device_id, outcome in (delivered|invalid|transient)} whose device set equals
-- claimed_device_ids exactly (no empty, malformed, unknown outcome, foreign device, missing
-- device, or duplicate). On any failure: return false, zero push_devices/push_outbox changes,
-- lease left intact.
create or replace function public.report_push_results(p_outbox_id uuid, p_claim_id uuid, p_results jsonb)
returns boolean language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare
  v_status text; v_claim uuid; v_attempts int; v_delivered uuid[]; v_claimed uuid[];
  e jsonb; v_dev uuid; v_out text;
  v_reported uuid[] := '{}'; v_new_delivered uuid[] := '{}'; v_invalid uuid[] := '{}'; v_transient int := 0;
begin
  select status, claim_id, attempts, delivered_device_ids, claimed_device_ids
    into v_status, v_claim, v_attempts, v_delivered, v_claimed
    from public.push_outbox where id = p_outbox_id for update;

  if not found or v_status <> 'processing' or v_claim is distinct from p_claim_id or v_claimed is null then
    return false;
  end if;
  if p_results is null or jsonb_typeof(p_results) <> 'array' or jsonb_array_length(p_results) = 0 then
    return false;
  end if;

  for e in select value from jsonb_array_elements(p_results) loop
    v_out := e->>'outcome';
    if v_out is null or v_out not in ('delivered','invalid','transient') then return false; end if;
    if (e->>'device_id') is null
       or (e->>'device_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      return false;
    end if;
    v_dev := (e->>'device_id')::uuid;
    if v_dev = any(v_reported) then return false; end if;              -- duplicate
    if not (v_dev = any(v_claimed)) then return false; end if;         -- foreign device
    v_reported := v_reported || v_dev;
    if v_out='delivered' then v_new_delivered := v_new_delivered || v_dev;
    elsif v_out='invalid' then v_invalid := v_invalid || v_dev;
    else v_transient := v_transient + 1; end if;
  end loop;
  if cardinality(v_reported) <> cardinality(v_claimed) then return false; end if;   -- missing device

  -- ===== validation passed; mutations begin =====
  if array_length(v_invalid,1) is not null then
    update public.push_devices set deleted_at=now(), enabled=false where id = any(v_invalid) and deleted_at is null;
  end if;
  v_delivered := (select coalesce(array_agg(distinct x),'{}') from unnest(coalesce(v_delivered,'{}') || v_new_delivered) x);

  if v_transient = 0 then
    update public.push_outbox set status='sent', delivered_device_ids=v_delivered,
      processed_at=now(), lease_expires_at=null, claim_id=null, claimed_device_ids=null where id=p_outbox_id;
  elsif v_attempts >= 8 then
    update public.push_outbox set status='dead', terminal_reason='max_attempts',
      delivered_device_ids=v_delivered, last_error='max_attempts_transient',
      processed_at=now(), lease_expires_at=null, claim_id=null, claimed_device_ids=null where id=p_outbox_id;
  else
    update public.push_outbox set status='failed', delivered_device_ids=v_delivered,
      last_error='transient', lease_expires_at=null, claim_id=null, claimed_device_ids=null,
      next_attempt_at = now() + (case v_attempts
        when 1 then interval '1 minute'  when 2 then interval '5 minutes'
        when 3 then interval '15 minutes' when 4 then interval '1 hour'
        when 5 then interval '3 hours'   else interval '6 hours' end) * (0.8 + random()*0.4)
      where id=p_outbox_id;
  end if;
  return true;
end $b$;

-- grants: worker role only; revoke the Supabase default-privilege grants from public/authenticated/anon
revoke all on function public.requeue_stale_push(int) from public, authenticated, anon;
revoke all on function public.claim_push_outbox(int,int) from public, authenticated, anon;
revoke all on function public.report_push_results(uuid,uuid,jsonb) from public, authenticated, anon;
grant execute on function public.requeue_stale_push(int) to push_worker;
grant execute on function public.claim_push_outbox(int,int) to push_worker;
grant execute on function public.report_push_results(uuid,uuid,jsonb) to push_worker;
