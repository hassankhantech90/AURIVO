-- Fix: real Supabase Auth signup failed with
--   ERROR: 42702: column reference "profile_id" is ambiguous
--
-- Root cause: public.assign_customer_role(profile_id uuid) declared a parameter
-- named `profile_id`. Inside the function, the `on conflict (profile_id, role_id)`
-- inference clause is ambiguous between that PL/pgSQL variable and the
-- public.profile_roles.profile_id column, so the whole signup trigger chain
-- (auth.users insert -> handle_new_user -> assign_customer_role, and
-- profiles insert -> assign_default_customer_role -> assign_customer_role)
-- aborted.
--
-- Fix: rename the parameter to `p_profile_id` so `profile_id` in the ON CONFLICT
-- clause unambiguously refers to the column. Behavior is otherwise identical.
--
-- A parameter cannot be renamed via CREATE OR REPLACE FUNCTION (Postgres raises
-- "cannot change name of input parameter"), so the function is dropped first and
-- recreated. There are no hard dependencies: the callers reference it by name
-- inside PL/pgSQL bodies (resolved at runtime), and the signature is unchanged.

drop function if exists public.assign_customer_role(uuid);

create or replace function public.assign_customer_role(p_profile_id uuid)
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
    values (p_profile_id, customer_role_id)
    on conflict (profile_id, role_id) do nothing;
  end if;
end;
$$;

-- Preserve the original security posture: this internal helper is only invoked
-- by SECURITY DEFINER trigger functions and must not be callable from the API
-- roles. (Recreating the function reset its ACL, so re-apply the revoke.)
revoke all on function public.assign_customer_role(uuid) from public, anon, authenticated;
