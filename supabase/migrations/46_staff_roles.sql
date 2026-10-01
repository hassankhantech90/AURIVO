-- Support & finance staff roles (Requirements Doc §2: "Support / Finance
-- admin: role-limited access to tickets, refunds or payout reconciliation;
-- activity must be logged"). The 'support' and 'finance' roles already exist
-- in public.roles; this grants them scoped powers. Admin keeps everything.
--
--   support : all support tickets; disputes (view, message, internal notes);
--             decide / receive returns; read orders & payments.
--   finance : record refunds; resolve disputes; dashboard; audit log;
--             read orders & payments.
-- Every action they take is already captured by the audit triggers (mig 45).

CREATE OR REPLACE FUNCTION public.has_any_role(role_names text[])
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.profile_roles pr ON pr.profile_id = p.id
    JOIN public.roles r ON r.id = pr.role_id
    WHERE p.user_id = auth.uid() AND p.deleted_at IS NULL
      AND r.name = ANY (role_names));
$$;
REVOKE ALL ON FUNCTION public.has_any_role(text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_any_role(text[]) TO authenticated;

-- Read access to the order domain for support & finance -----------------------------
CREATE POLICY orders_staff_select ON public.orders FOR SELECT TO authenticated
  USING (has_any_role(ARRAY['support', 'finance']));
CREATE POLICY order_items_staff_select ON public.order_items FOR SELECT TO authenticated
  USING (has_any_role(ARRAY['support', 'finance']));
CREATE POLICY payments_staff_select ON public.payments FOR SELECT TO authenticated
  USING (has_any_role(ARRAY['support', 'finance']));
CREATE POLICY shipments_staff_select ON public.shipments FOR SELECT TO authenticated
  USING (has_any_role(ARRAY['support', 'finance']));
CREATE POLICY order_status_history_staff_select ON public.order_status_history
  FOR SELECT TO authenticated USING (has_any_role(ARRAY['support', 'finance']));
CREATE POLICY return_requests_staff_select ON public.return_requests
  FOR SELECT TO authenticated USING (has_any_role(ARRAY['support', 'finance']));

-- Support tickets: support staff see and work every ticket ------------------------------
CREATE POLICY support_tickets_support_select ON public.support_tickets
  FOR SELECT TO authenticated USING (has_role('support'));
CREATE POLICY support_tickets_support_update ON public.support_tickets
  FOR UPDATE TO authenticated USING (has_role('support')) WITH CHECK (has_role('support'));

-- Audit log: finance can read it --------------------------------------------------------
CREATE POLICY audit_logs_finance_select ON public.audit_logs
  FOR SELECT TO authenticated USING (has_role('finance'));

-- Internal dispute notes: staff, not just admins ------------------------------------------
DROP POLICY IF EXISTS dispute_messages_participant_select ON public.dispute_messages;
CREATE POLICY dispute_messages_participant_select ON public.dispute_messages
  FOR SELECT TO authenticated
  USING (public.is_dispute_participant(dispute_id)
         AND (NOT is_internal OR has_any_role(ARRAY['admin', 'support', 'finance'])));
DROP POLICY IF EXISTS dispute_messages_participant_insert ON public.dispute_messages;
CREATE POLICY dispute_messages_participant_insert ON public.dispute_messages
  FOR INSERT TO authenticated
  WITH CHECK (author_profile_id = current_profile_id()
              AND public.is_dispute_participant(dispute_id)
              AND (NOT is_internal OR has_any_role(ARRAY['admin', 'support', 'finance']))
              AND EXISTS (SELECT 1 FROM public.disputes d
                          WHERE d.id = dispute_id AND d.status = 'open'));

-- Widen the role check inside existing functions ---------------------------------------
-- Each replacement must match exactly once, otherwise the migration aborts.
DO $$
declare
  r record;
  v_def text;
  v_new text;
begin
  for r in select * from (values
    ('public.is_dispute_participant(uuid)',
     $q$SELECT has_role('admin') OR EXISTS ($q$,
     $q$SELECT has_any_role(ARRAY['admin','support','finance']) OR EXISTS ($q$),
    ('public.resolve_dispute(uuid,text,numeric,text)',
     $q$if not has_role('admin') then$q$,
     $q$if not has_any_role(array['admin','finance']) then$q$),
    ('public.mark_return_refunded(uuid,text)',
     $q$if not has_role('admin') then$q$,
     $q$if not has_any_role(array['admin','finance']) then$q$),
    ('public.decide_return(uuid,boolean,text)',
     $q$if not (has_role('admin') or is_order_seller(v_row.order_id)) then$q$,
     $q$if not (has_any_role(array['admin','support']) or is_order_seller(v_row.order_id)) then$q$),
    ('public.mark_return_received(uuid)',
     $q$if not (has_role('admin') or is_order_seller(v_row.order_id)) then$q$,
     $q$if not (has_any_role(array['admin','support']) or is_order_seller(v_row.order_id)) then$q$),
    ('public.admin_dashboard_stats(integer)',
     $q$if not has_role('admin') then$q$,
     $q$if not has_any_role(array['admin','finance']) then$q$),
    ('public.verify_audit_chain()',
     $q$if not has_role('admin') then$q$,
     $q$if not has_any_role(array['admin','finance']) then$q$),
    ('public.enforce_support_ticket_owner_fields()',
     $q$if auth.uid() is null or has_role('admin') then return NEW; end if;$q$,
     $q$if auth.uid() is null or has_any_role(array['admin','support']) then return NEW; end if;$q$)
  ) as x(fn, old_text, new_text)
  loop
    v_def := pg_get_functiondef(r.fn::regprocedure);
    if (length(v_def) - length(replace(v_def, r.old_text, ''))) / length(r.old_text) <> 1 then
      raise exception 'Expected exactly one "%" in %', r.old_text, r.fn;
    end if;
    v_new := replace(v_def, r.old_text, r.new_text);
    execute v_new;
  end loop;
end $$;
