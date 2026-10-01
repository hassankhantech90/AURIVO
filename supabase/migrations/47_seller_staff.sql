-- Seller staff (Requirements Doc §2: "Seller staff — restricted access
-- selected by seller: catalogue, orders or customer messages; no payout/bank
-- changes by default").
--
-- * seller_staff: store <-> staff profile with permission flags; owner-managed
--   through RPCs only (staff can read their own rows).
-- * seller_can(store, perm): owner OR active staff with that permission.
-- * Every owner check of the form `sp.profile_id = current_profile_id()` in
--   catalogue/order policies and seller functions becomes
--   seller_can(sp.id, 'catalog' | 'orders'). Rewritten programmatically from
--   the live definitions; aborts if an expected rewrite doesn't happen.
-- * NOT granted to staff: store settings / bank & payout (seller_profiles
--   UPDATE stays owner-only — that policy checks profile_id directly).
-- * Customer messages: the flag is stored, but chat access for staff is a
--   follow-up (chat RLS is per-participant).

CREATE TABLE public.seller_staff (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_profile_id uuid NOT NULL REFERENCES public.seller_profiles(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  can_catalog boolean NOT NULL DEFAULT false,
  can_orders boolean NOT NULL DEFAULT false,
  can_messages boolean NOT NULL DEFAULT false,
  invited_by uuid REFERENCES public.profiles(id),
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT seller_staff_unique UNIQUE (seller_profile_id, profile_id)
);
CREATE TRIGGER seller_staff_set_updated_at BEFORE UPDATE ON public.seller_staff
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
ALTER TABLE public.seller_staff ENABLE ROW LEVEL SECURITY;
CREATE POLICY seller_staff_self_select ON public.seller_staff
  FOR SELECT TO authenticated USING (profile_id = current_profile_id() OR has_role('admin'));
-- Audit staff grants (mig 45).
CREATE TRIGGER seller_staff_audit AFTER INSERT OR UPDATE OR DELETE ON public.seller_staff
  FOR EACH ROW EXECUTE FUNCTION public.audit_change();

CREATE OR REPLACE FUNCTION public.seller_can(p_seller_profile_id uuid, p_permission text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
      SELECT 1 FROM public.seller_profiles sp
      WHERE sp.id = p_seller_profile_id AND sp.profile_id = current_profile_id()
        AND sp.deleted_at IS NULL)
    OR EXISTS (
      SELECT 1 FROM public.seller_staff s
      JOIN public.seller_profiles sp ON sp.id = s.seller_profile_id AND sp.deleted_at IS NULL
      WHERE s.seller_profile_id = p_seller_profile_id
        AND s.profile_id = current_profile_id()
        AND s.revoked_at IS NULL
        AND CASE p_permission
              WHEN 'catalog' THEN s.can_catalog
              WHEN 'orders' THEN s.can_orders
              WHEN 'messages' THEN s.can_messages
              ELSE false END);
$$;
REVOKE ALL ON FUNCTION public.seller_can(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seller_can(uuid, text) TO authenticated;

-- The store the caller works on: their own, else the first store that
-- employs them (optionally requiring a permission).
CREATE OR REPLACE FUNCTION public.my_seller_store(p_permission text DEFAULT NULL)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT id FROM (
    SELECT sp.id, 0 AS rank FROM public.seller_profiles sp
    WHERE sp.profile_id = current_profile_id() AND sp.deleted_at IS NULL
    UNION ALL
    SELECT s.seller_profile_id, 1 FROM public.seller_staff s
    JOIN public.seller_profiles sp ON sp.id = s.seller_profile_id AND sp.deleted_at IS NULL
    WHERE s.profile_id = current_profile_id() AND s.revoked_at IS NULL
      AND (p_permission IS NULL OR public.seller_can(s.seller_profile_id, p_permission))
  ) x ORDER BY rank LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.my_seller_store(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.my_seller_store(text) TO authenticated;

-- Owner team management ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_seller_staff()
RETURNS TABLE (id uuid, profile_id uuid, full_name text, email text,
               can_catalog boolean, can_orders boolean, can_messages boolean,
               revoked_at timestamptz, created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT s.id, s.profile_id, p.full_name, p.email,
         s.can_catalog, s.can_orders, s.can_messages, s.revoked_at, s.created_at
  FROM public.seller_staff s
  JOIN public.seller_profiles sp ON sp.id = s.seller_profile_id
  JOIN public.profiles p ON p.id = s.profile_id
  WHERE sp.profile_id = current_profile_id() AND sp.deleted_at IS NULL
  ORDER BY s.revoked_at NULLS FIRST, s.created_at;
$$;

CREATE OR REPLACE FUNCTION public.add_seller_staff(
  p_email text, p_catalog boolean, p_orders boolean, p_messages boolean DEFAULT false)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_store uuid; v_staff uuid; v_id uuid;
begin
  select id into v_store from public.seller_profiles
  where profile_id = current_profile_id() and deleted_at is null;
  if v_store is null then
    raise exception 'Only a store owner can add staff.' using errcode = '42501';
  end if;
  if not (p_catalog or p_orders or p_messages) then
    raise exception 'Choose at least one permission.';
  end if;
  select id into v_staff from public.profiles
  where lower(email) = lower(btrim(p_email)) and deleted_at is null;
  if v_staff is null then
    raise exception 'No AURIVO account uses that email. Ask them to sign up first.';
  end if;
  if v_staff = current_profile_id() then
    raise exception 'You already own this store.';
  end if;

  insert into public.seller_staff
    (seller_profile_id, profile_id, can_catalog, can_orders, can_messages, invited_by)
  values (v_store, v_staff, p_catalog, p_orders, p_messages, current_profile_id())
  on conflict (seller_profile_id, profile_id) do update
    set can_catalog = excluded.can_catalog, can_orders = excluded.can_orders,
        can_messages = excluded.can_messages, revoked_at = null
  returning id into v_id;

  insert into public.notifications(profile_id, type, title, body, data)
  select v_staff, 'seller_event', 'You were added to a store team',
         'You now have staff access to ' || sp.store_name || ' in Seller Studio.',
         jsonb_build_object('event', 'staff_added', 'seller_profile_id', v_store::text,
           'route', '/seller-studio')
  from public.seller_profiles sp where sp.id = v_store;
  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_seller_staff(
  p_staff_id uuid, p_catalog boolean, p_orders boolean, p_messages boolean,
  p_revoke boolean DEFAULT false)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  update public.seller_staff s
  set can_catalog = p_catalog, can_orders = p_orders, can_messages = p_messages,
      revoked_at = case when p_revoke then now() else null end
  from public.seller_profiles sp
  where s.id = p_staff_id and sp.id = s.seller_profile_id
    and sp.profile_id = current_profile_id() and sp.deleted_at is null;
  if not found then
    raise exception 'Staff member not found in your store.' using errcode = '42501';
  end if;
end;
$function$;

REVOKE ALL ON FUNCTION public.my_seller_staff() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.add_seller_staff(text, boolean, boolean, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_seller_staff(uuid, boolean, boolean, boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.my_seller_staff() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_seller_staff(text, boolean, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_seller_staff(uuid, boolean, boolean, boolean, boolean) TO authenticated;

-- Rewrite owner checks to seller_can ---------------------------------------------------
DO $$
declare
  p record;
  v_perm text;
  v_qual text;
  v_check text;
  v_roles text;
  v_count int := 0;
  v_pattern constant text := 'sp.profile_id = current_profile_id()';
begin
  for p in
    select * from pg_policies
    where (coalesce(qual, '') || coalesce(with_check, '')) like '%' || v_pattern || '%'
  loop
    v_perm := case
      when p.tablename in ('products', 'product_variants', 'product_images',
                           'product_price_tiers', 'product_categories',
                           'product_variant_attributes', 'inventory_movements', 'objects')
        then 'catalog'
      else 'orders' end;
    v_qual := replace(p.qual, v_pattern, format('public.seller_can(sp.id, %L)', v_perm));
    v_check := replace(p.with_check, v_pattern, format('public.seller_can(sp.id, %L)', v_perm));
    select string_agg(quote_ident(r), ', ') into v_roles from unnest(p.roles) r;
    execute format('DROP POLICY %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    execute format('CREATE POLICY %I ON %I.%I AS %s FOR %s TO %s%s%s',
      p.policyname, p.schemaname, p.tablename, p.permissive, p.cmd, v_roles,
      case when v_qual is null then '' else format(' USING (%s)', v_qual) end,
      case when v_check is null then '' else format(' WITH CHECK (%s)', v_check) end);
    v_count := v_count + 1;
  end loop;
  if v_count < 20 then
    raise exception 'Expected to rewrite ~22 seller policies, rewrote %', v_count;
  end if;
  raise notice 'rewrote % seller policies', v_count;
end $$;

DO $$
declare r record; v_def text; v_n int;
begin
  for r in select * from (values
    ('public.is_order_seller(uuid)', 'orders'),
    ('public.seller_orders()', 'orders'),
    ('public.seller_order_header(uuid)', 'orders'),
    ('public.seller_insights(integer)', 'orders'),
    ('public.record_product_view(uuid)', 'catalog'),
    ('public.is_dispute_participant(uuid)', 'orders')
  ) as x(fn, perm)
  loop
    v_def := pg_get_functiondef(r.fn::regprocedure);
    v_n := (length(v_def) - length(replace(v_def, 'sp.profile_id = current_profile_id()', '')))
           / length('sp.profile_id = current_profile_id()');
    if v_n < 1 then
      raise exception 'No owner check found in %', r.fn;
    end if;
    execute replace(v_def, 'sp.profile_id = current_profile_id()',
                    format('public.seller_can(sp.id, %L)', r.perm));
  end loop;
end $$;
