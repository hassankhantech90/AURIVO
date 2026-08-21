-- Phase 22 / migration 22 — push device registry (P1, storage only).
-- Applied live as migration 22_push_devices.
--
-- Server-owned via SECURITY DEFINER RPCs; clients read own rows only and never
-- write directly or pass a profile_id. Invariants (enforced by partial unique
-- indexes plus reassignment logic serialized by sorted advisory locks):
--   one active installation_id -> at most one profile
--   one active push_token      -> at most one installation
-- permission_status (OS authorization) is kept separate from enabled (app-level
-- user choice); e.g. permission_status='denied' with enabled=true is valid.
-- A profile soft-delete cascades to its devices. Android/iOS only (web push
-- deferred). No pg_net/pg_cron and no dispatch here — that is P2.

create table public.push_devices (
  id                uuid primary key default gen_random_uuid(),
  profile_id        uuid not null references public.profiles(id) on delete cascade,
  installation_id   text not null,
  platform          text not null check (platform in ('android','ios')),
  push_token        text not null,
  permission_status text not null default 'not_determined'
                      check (permission_status in ('not_determined','denied','granted','provisional')),
  enabled           boolean not null default true,
  app_version       text,
  os_version        text,
  token_updated_at  timestamptz not null default now(),
  last_seen_at      timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);

create unique index push_devices_installation_active on public.push_devices (installation_id) where deleted_at is null;
create unique index push_devices_token_active        on public.push_devices (push_token)      where deleted_at is null;
create index        push_devices_profile_active      on public.push_devices (profile_id)       where deleted_at is null;
create index        push_devices_last_seen           on public.push_devices (last_seen_at)     where deleted_at is null;

create trigger push_devices_set_updated_at before update on public.push_devices
  for each row execute function public.set_updated_at();

alter table public.push_devices enable row level security;
create policy push_devices_select_own on public.push_devices
  for select to authenticated using (profile_id = current_profile_id());
revoke insert, update, delete, truncate on public.push_devices from authenticated, anon;
revoke select on public.push_devices from anon;

-- Registration: find-or-create by installation, owner = current_profile_id(),
-- enforcing both invariants and reassigning stale ownership server-side. enabled
-- is preserved on update (incl. A->B reassignment); token_updated_at bumps only
-- when the token actually changes.
create or replace function public.register_push_device(
  p_installation_id text, p_platform text, p_token text,
  p_permission_status text default 'granted',
  p_app_version text default null, p_os_version text default null
) returns uuid language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_profile uuid := current_profile_id(); v_id uuid; v_h_inst bigint; v_h_tok bigint;
begin
  if v_profile is null then raise exception 'not_authenticated' using errcode='28000'; end if;
  if coalesce(trim(p_installation_id),'')='' or coalesce(trim(p_token),'')='' then
    raise exception 'installation_id and token required' using errcode='22023'; end if;
  if p_platform not in ('android','ios') then
    raise exception 'unsupported platform %', p_platform using errcode='22023'; end if;
  if p_permission_status not in ('not_determined','denied','granted','provisional') then
    raise exception 'invalid permission_status' using errcode='22023'; end if;

  v_h_inst := hashtextextended('push_inst:'||p_installation_id, 0);
  v_h_tok  := hashtextextended('push_tok:'||p_token, 0);
  perform pg_advisory_xact_lock(least(v_h_inst, v_h_tok));
  if v_h_inst <> v_h_tok then perform pg_advisory_xact_lock(greatest(v_h_inst, v_h_tok)); end if;

  update public.push_devices set deleted_at = now(), enabled = false
   where push_token = p_token and deleted_at is null and installation_id <> p_installation_id;

  select id into v_id from public.push_devices
   where installation_id = p_installation_id and deleted_at is null limit 1;

  if v_id is not null then
    update public.push_devices set
      profile_id = v_profile,
      push_token = p_token,
      platform = p_platform,
      permission_status = p_permission_status,
      app_version = coalesce(p_app_version, app_version),
      os_version = coalesce(p_os_version, os_version),
      token_updated_at = case when push_token is distinct from p_token then now() else token_updated_at end,
      last_seen_at = now()
     where id = v_id;
  else
    insert into public.push_devices(profile_id, installation_id, platform, push_token,
                                    permission_status, app_version, os_version)
    values (v_profile, p_installation_id, p_platform, p_token, p_permission_status, p_app_version, p_os_version)
    returning id into v_id;
  end if;
  return v_id;
end $b$;

create or replace function public.unregister_push_device(p_installation_id text)
returns void language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_profile uuid := current_profile_id();
begin
  if v_profile is null then raise exception 'not_authenticated' using errcode='28000'; end if;
  update public.push_devices set deleted_at = now(), enabled = false
   where installation_id = p_installation_id and deleted_at is null and profile_id = v_profile;
end $b$;

create or replace function public.set_push_permission(p_installation_id text, p_status text)
returns void language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_profile uuid := current_profile_id();
begin
  if v_profile is null then raise exception 'not_authenticated' using errcode='28000'; end if;
  if p_status not in ('not_determined','denied','granted','provisional') then
    raise exception 'invalid permission_status' using errcode='22023'; end if;
  update public.push_devices set permission_status = p_status, last_seen_at = now()
   where installation_id = p_installation_id and deleted_at is null and profile_id = v_profile;
end $b$;

create or replace function public.set_push_enabled(p_installation_id text, p_enabled boolean)
returns void language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_profile uuid := current_profile_id();
begin
  if v_profile is null then raise exception 'not_authenticated' using errcode='28000'; end if;
  update public.push_devices set enabled = p_enabled, last_seen_at = now()
   where installation_id = p_installation_id and deleted_at is null and profile_id = v_profile;
end $b$;

revoke all on function public.register_push_device(text,text,text,text,text,text) from public;
revoke all on function public.unregister_push_device(text) from public;
revoke all on function public.set_push_permission(text,text) from public;
revoke all on function public.set_push_enabled(text,boolean) from public;
grant execute on function public.register_push_device(text,text,text,text,text,text) to authenticated;
grant execute on function public.unregister_push_device(text) to authenticated;
grant execute on function public.set_push_permission(text,text) to authenticated;
grant execute on function public.set_push_enabled(text,boolean) to authenticated;

-- Account soft-delete cascade: soft-delete a profile's devices when the profile
-- is soft-deleted (hard deletes cascade via the FK).
create or replace function public.push_devices_on_profile_soft_delete()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
begin
  if OLD.deleted_at is null and NEW.deleted_at is not null then
    update public.push_devices set deleted_at = now(), enabled = false
     where profile_id = NEW.id and deleted_at is null;
  end if;
  return NEW;
end $b$;
create trigger profiles_soft_delete_push_devices after update of deleted_at on public.profiles
  for each row execute function public.push_devices_on_profile_soft_delete();
