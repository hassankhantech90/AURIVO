-- MFA for admin roles (Requirements Doc §9: "MFA for admin roles").
--
-- Once a staff member (admin / support / finance) has a VERIFIED MFA factor,
-- their staff powers only count on a session that completed the second factor
-- (JWT claim aal = 'aal2'). A stolen password alone then grants nothing.
-- Staff who haven't enrolled yet keep working (bootstrap) — the app requires
-- them to enrol before the staff console opens.
-- Non-staff roles (customer, seller, business_buyer) are unaffected.

CREATE OR REPLACE FUNCTION public.staff_mfa_satisfied()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth
AS $$
  SELECT coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
      OR NOT EXISTS (SELECT 1 FROM auth.mfa_factors f
                     WHERE f.user_id = auth.uid() AND f.status = 'verified');
$$;
REVOKE ALL ON FUNCTION public.staff_mfa_satisfied() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.staff_mfa_satisfied() TO authenticated;

CREATE OR REPLACE FUNCTION public.has_role(role_name text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1
    from public.profiles p
    join public.profile_roles pr on pr.profile_id = p.id
    join public.roles r on r.id = pr.role_id
    where p.user_id = auth.uid()
      and p.deleted_at is null
      and r.name = role_name
  )
  and (role_name not in ('admin', 'support', 'finance')
       or public.staff_mfa_satisfied())
$function$;

CREATE OR REPLACE FUNCTION public.has_any_role(role_names text[])
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.profile_roles pr ON pr.profile_id = p.id
    JOIN public.roles r ON r.id = pr.role_id
    WHERE p.user_id = auth.uid() AND p.deleted_at IS NULL
      AND r.name = ANY (role_names)
      AND (r.name NOT IN ('admin', 'support', 'finance')
           OR public.staff_mfa_satisfied()));
$function$;
