-- Phase 12D — User & role guards
-- Applied live as migration 13_user_role_guards.
--
-- 1. Reserve profiles.status / deleted_at changes to admins. profiles_update_own
--    enforces ownership but not which columns change, so a user could otherwise
--    un-suspend or un-delete themselves. Admins and service/definer contexts
--    (auth.uid() is null — e.g. the signup profile-creation trigger) bypass.
create or replace function public.enforce_profile_admin_fields()
returns trigger
language plpgsql
as $body$
begin
  if auth.uid() is null or has_role('admin') then
    return NEW;
  end if;
  if TG_OP = 'INSERT' then
    if NEW.status <> 'active' or NEW.deleted_at is not null then
      raise exception 'Only an administrator can set account status'
        using errcode = '42501';
    end if;
  elsif TG_OP = 'UPDATE' then
    if NEW.status is distinct from OLD.status
       or NEW.deleted_at is distinct from OLD.deleted_at then
      raise exception 'Only an administrator can change account status'
        using errcode = '42501';
    end if;
  end if;
  return NEW;
end
$body$;

-- 2. Never remove the last active administrator. Applies to everyone (incl.
--    admins) to prevent accidental self-lockout; a superuser can still disable
--    the trigger for genuine DB maintenance.
create or replace function public.enforce_last_admin()
returns trigger
language plpgsql
as $body$
declare
  admin_role uuid;
  remaining int;
begin
  select id into admin_role from public.roles where name = 'admin';
  if (TG_OP = 'DELETE' and OLD.role_id = admin_role)
     or (TG_OP = 'UPDATE' and OLD.role_id = admin_role
         and NEW.role_id is distinct from admin_role) then
    select count(*) into remaining
    from public.profile_roles pr
    join public.profiles p on p.id = pr.profile_id
    where pr.role_id = admin_role
      and pr.profile_id <> OLD.profile_id
      and p.deleted_at is null;
    if remaining = 0 then
      raise exception 'Cannot remove the last administrator'
        using errcode = '42501';
    end if;
  end if;
  return case when TG_OP = 'DELETE' then OLD else NEW end;
end
$body$;

drop trigger if exists profiles_admin_fields_guard on public.profiles;
create trigger profiles_admin_fields_guard
  before insert or update on public.profiles
  for each row execute function public.enforce_profile_admin_fields();

drop trigger if exists profile_roles_last_admin_guard on public.profile_roles;
create trigger profile_roles_last_admin_guard
  before update or delete on public.profile_roles
  for each row execute function public.enforce_last_admin();
