-- Tamper-evident audit log (Requirements Doc §9: "audit logs for finance,
-- approvals and user data changes"; §8 "tamper-evident activity log").
--
-- * audit_change(): generic AFTER trigger. Logs INSERT/DELETE rows and, for
--   UPDATE, only the changed columns (ignoring updated_at). Optional TG_ARGV[0]
--   = comma-separated watched columns: an UPDATE is logged only if one of
--   them changed (so routine edits like a product description aren't noise).
-- * Hash chain: every entry stores prev_hash + row_hash = sha256(prev_hash |
--   seq | table | record | action | actor | old | new | created_at). Altering
--   or removing an entry breaks the chain; verify_audit_chain() finds where.
-- * Append-only: no client INSERT (the old admin INSERT policy let an admin
--   forge entries) and UPDATE/DELETE are blocked by trigger for everyone.

ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS seq bigint GENERATED ALWAYS AS IDENTITY,
  ADD COLUMN IF NOT EXISTS changed_fields text[],
  ADD COLUMN IF NOT EXISTS prev_hash text,
  ADD COLUMN IF NOT EXISTS row_hash text;
CREATE UNIQUE INDEX IF NOT EXISTS audit_logs_seq_idx ON public.audit_logs (seq);
CREATE INDEX IF NOT EXISTS audit_logs_table_created_idx
  ON public.audit_logs (table_name, created_at DESC);

DROP POLICY IF EXISTS audit_logs_admin_insert ON public.audit_logs;

CREATE OR REPLACE FUNCTION public.audit_row_hash(a public.audit_logs)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = public, extensions
AS $$
  SELECT encode(extensions.digest(concat_ws('|',
    coalesce(a.prev_hash, ''), a.seq::text, a.table_name,
    coalesce(a.record_id::text, ''), a.action, coalesce(a.performed_by::text, ''),
    coalesce(a.old_values::text, ''), coalesce(a.new_values::text, ''),
    extract(epoch from a.created_at)::text), 'sha256'), 'hex');
$$;

-- Chain each new entry to the previous one (serialised by an advisory lock).
CREATE OR REPLACE FUNCTION public.audit_logs_chain()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  perform pg_advisory_xact_lock(hashtext('aurivo_audit_chain'));
  select row_hash into NEW.prev_hash from public.audit_logs
  order by seq desc limit 1;
  NEW.row_hash := public.audit_row_hash(NEW);
  return NEW;
end;
$function$;
DROP TRIGGER IF EXISTS audit_logs_chain ON public.audit_logs;
CREATE TRIGGER audit_logs_chain BEFORE INSERT ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.audit_logs_chain();

CREATE OR REPLACE FUNCTION public.audit_logs_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
begin
  raise exception 'Audit log entries cannot be changed or deleted.'
    using errcode = '42501';
end;
$function$;
DROP TRIGGER IF EXISTS audit_logs_immutable ON public.audit_logs;
CREATE TRIGGER audit_logs_immutable BEFORE UPDATE OR DELETE ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.audit_logs_immutable();

-- Generic change capture ----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.audit_change()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_old jsonb := case when TG_OP in ('UPDATE', 'DELETE') then to_jsonb(OLD) end;
  v_new jsonb := case when TG_OP in ('INSERT', 'UPDATE') then to_jsonb(NEW) end;
  v_watch text[] := case when TG_NARGS > 0 then string_to_array(TG_ARGV[0], ',') end;
  v_changed text[];
  v_row jsonb := coalesce(v_new, v_old);
begin
  if TG_OP = 'UPDATE' then
    select array_agg(n.key order by n.key) into v_changed
    from jsonb_each(v_new) n
    where n.key <> 'updated_at' and n.value is distinct from v_old -> n.key;
    if v_changed is null then return null; end if;
    if v_watch is not null and not (v_changed && v_watch) then return null; end if;
    select jsonb_object_agg(k, v_old -> k), jsonb_object_agg(k, v_new -> k)
      into v_old, v_new
    from unnest(v_changed) k;
  end if;

  insert into public.audit_logs
    (table_name, record_id, action, performed_by, old_values, new_values, changed_fields)
  values (
    TG_TABLE_NAME,
    case when v_row ? 'id' then (v_row ->> 'id')::uuid end,
    lower(TG_OP),
    public.current_profile_id(),
    v_old, v_new, v_changed);
  return null;
end;
$function$;

-- Attach: approvals, roles, finance, account status, content ------------------
DO $$
declare t record;
begin
  for t in select * from (values
    ('seller_profiles',   'INSERT OR UPDATE OR DELETE', 'verification_status,commission_rate,deleted_at'),
    ('business_profiles', 'INSERT OR UPDATE OR DELETE', 'verification_status,deleted_at'),
    ('products',          'UPDATE OR DELETE',           'status,featured,deleted_at'),
    ('profiles',          'UPDATE',                     'status,deleted_at'),
    ('profile_roles',     'INSERT OR UPDATE OR DELETE', null),
    ('orders',            'INSERT OR UPDATE OR DELETE', 'status,payment_status,grand_total,discount_total,deleted_at'),
    ('payments',          'INSERT OR UPDATE OR DELETE', null),
    ('return_requests',   'INSERT OR UPDATE',           'status'),
    ('disputes',          'INSERT OR UPDATE',           'status,resolution,refund_amount'),
    ('coupons',           'INSERT OR UPDATE OR DELETE', null),
    ('cms_pages',         'INSERT OR UPDATE OR DELETE', null),
    ('cms_banners',       'INSERT OR UPDATE OR DELETE', null)
  ) as x(tbl, ops, watch)
  loop
    execute format('DROP TRIGGER IF EXISTS %I ON public.%I', t.tbl || '_audit', t.tbl);
    execute format(
      'CREATE TRIGGER %I AFTER %s ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_change(%s)',
      t.tbl || '_audit', t.ops, t.tbl,
      case when t.watch is null then '' else quote_literal(t.watch) end);
  end loop;
end $$;

-- Integrity check (admin) -------------------------------------------------------------
-- Returns null when the whole chain verifies, else the seq of the first bad entry.
CREATE OR REPLACE FUNCTION public.verify_audit_chain()
RETURNS bigint
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare a public.audit_logs; v_prev text := null;
begin
  if not has_role('admin') then
    raise exception 'Only administrators can verify the audit log.' using errcode = '42501';
  end if;
  for a in select * from public.audit_logs order by seq loop
    if a.prev_hash is distinct from v_prev or a.row_hash is distinct from public.audit_row_hash(a) then
      return a.seq;
    end if;
    v_prev := a.row_hash;
  end loop;
  return null;
end;
$function$;
REVOKE ALL ON FUNCTION public.verify_audit_chain() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_audit_chain() TO authenticated;
