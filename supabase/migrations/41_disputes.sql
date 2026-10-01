-- Dispute centre (Requirements Doc §6: "buyer/seller conversation, evidence
-- upload, resolution, refund decision and internal notes"; §4.2 "Disputed").
--
-- * disputes: one OPEN dispute per order, opened by the order's buyer or one
--   of its sellers once the order has shipped. Admin resolves it with a
--   refund decision (money movement waits for the payment provider; for COD
--   the refund is recorded and paid manually).
-- * dispute_messages: the conversation. Participants = the order's buyer,
--   the order's sellers, and admins. is_internal notes are admin-only.
-- * dispute-evidence storage bucket (PRIVATE): files under <dispute_id>/...,
--   readable/uploadable by participants only (signed URLs in the app).
-- * Also guards support_tickets: owners could change priority / assignee /
--   status of their own ticket (assigning it to any profile exposed it).

CREATE TABLE public.disputes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  opened_by uuid NOT NULL REFERENCES public.profiles(id),
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'open',
  resolution text,
  refund_amount numeric(12,2),
  resolution_note text,
  resolved_by uuid REFERENCES public.profiles(id),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT disputes_status_check CHECK (status IN ('open', 'resolved', 'withdrawn')),
  CONSTRAINT disputes_reason_check CHECK (reason IN
    ('not_received', 'damaged', 'not_as_described', 'counterfeit',
     'return_issue', 'payment_issue', 'other')),
  CONSTRAINT disputes_resolution_check CHECK (resolution IS NULL OR resolution IN
    ('refund_full', 'refund_partial', 'no_refund')),
  CONSTRAINT disputes_refund_amount_check CHECK (refund_amount IS NULL OR refund_amount >= 0)
);
CREATE INDEX disputes_order_id_idx ON public.disputes (order_id);
CREATE INDEX disputes_status_idx ON public.disputes (status);
CREATE UNIQUE INDEX disputes_one_open_per_order ON public.disputes (order_id)
  WHERE status = 'open';
CREATE TRIGGER disputes_set_updated_at BEFORE UPDATE ON public.disputes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.dispute_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id uuid NOT NULL REFERENCES public.disputes(id) ON DELETE CASCADE,
  author_profile_id uuid NOT NULL REFERENCES public.profiles(id),
  body text NOT NULL,
  is_internal boolean NOT NULL DEFAULT false,
  attachments jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dispute_messages_body_check CHECK (char_length(btrim(body)) >= 1),
  CONSTRAINT dispute_messages_attachments_check CHECK (jsonb_typeof(attachments) = 'array')
);
CREATE INDEX dispute_messages_dispute_id_idx ON public.dispute_messages (dispute_id, created_at);

-- Participant check ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_dispute_participant(p_dispute_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT has_role('admin') OR EXISTS (
    SELECT 1 FROM public.disputes d
    JOIN public.orders o ON o.id = d.order_id
    WHERE d.id = p_dispute_id
      AND (o.profile_id = current_profile_id()
           OR EXISTS (SELECT 1 FROM public.order_items oi
                      JOIN public.seller_profiles sp ON sp.id = oi.seller_id
                      WHERE oi.order_id = o.id
                        AND sp.profile_id = current_profile_id()
                        AND sp.deleted_at IS NULL)));
$$;
REVOKE ALL ON FUNCTION public.is_dispute_participant(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_dispute_participant(uuid) TO authenticated;

-- RLS ---------------------------------------------------------------------------------
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispute_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY disputes_participant_select ON public.disputes
  FOR SELECT TO authenticated USING (public.is_dispute_participant(id));

CREATE POLICY dispute_messages_participant_select ON public.dispute_messages
  FOR SELECT TO authenticated
  USING (public.is_dispute_participant(dispute_id)
         AND (NOT is_internal OR has_role('admin')));

CREATE POLICY dispute_messages_participant_insert ON public.dispute_messages
  FOR INSERT TO authenticated
  WITH CHECK (author_profile_id = current_profile_id()
              AND public.is_dispute_participant(dispute_id)
              AND (NOT is_internal OR has_role('admin'))
              AND EXISTS (SELECT 1 FROM public.disputes d
                          WHERE d.id = dispute_id AND d.status = 'open'));

-- Notify the other participants of a new (non-internal) message.
CREATE OR REPLACE FUNCTION public.notify_dispute_message()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_order uuid;
begin
  if NEW.is_internal then return NEW; end if;
  select order_id into v_order from public.disputes where id = NEW.dispute_id;
  insert into public.notifications(profile_id, type, title, body, data)
  select p.pid, 'support', 'Dispute update',
         'There is a new message on a dispute about one of your orders.',
         jsonb_build_object('event', 'dispute_message', 'dispute_id', NEW.dispute_id::text,
           'order_id', v_order::text, 'route', '/disputes/' || NEW.dispute_id::text)
  from (
    select o.profile_id as pid from public.orders o where o.id = v_order
    union
    select sp.profile_id from public.order_items oi
      join public.seller_profiles sp on sp.id = oi.seller_id and sp.deleted_at is null
      where oi.order_id = v_order
  ) p
  where p.pid <> NEW.author_profile_id;
  return NEW;
end;
$function$;
CREATE TRIGGER dispute_messages_notify AFTER INSERT ON public.dispute_messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_dispute_message();

-- Open a dispute ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.open_dispute(
  p_order_id uuid, p_reason text, p_description text)
RETURNS public.disputes
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_profile uuid := current_profile_id();
  v_order public.orders;
  v_row public.disputes;
begin
  if v_profile is null then raise exception 'Authentication required.'; end if;
  if nullif(btrim(p_description), '') is null then
    raise exception 'Please describe the problem.';
  end if;

  select * into v_order from public.orders where id = p_order_id and deleted_at is null;
  if not found then raise exception 'Order not found.'; end if;
  if not (v_order.profile_id = v_profile or public.is_order_seller(p_order_id)) then
    raise exception 'Only the buyer or a seller on this order can open a dispute.'
      using errcode = '42501';
  end if;
  if v_order.status not in ('shipped', 'delivered', 'completed', 'returned') then
    raise exception 'Disputes can be opened once an order has shipped.';
  end if;
  if exists (select 1 from public.disputes where order_id = p_order_id and status = 'open') then
    raise exception 'A dispute is already open for this order.';
  end if;

  insert into public.disputes (order_id, opened_by, reason)
  values (p_order_id, v_profile, p_reason)
  returning * into v_row;

  insert into public.dispute_messages (dispute_id, author_profile_id, body)
  values (v_row.id, v_profile, btrim(p_description));

  -- Admins see every new dispute.
  insert into public.notifications(profile_id, type, title, body, data)
  select distinct p.id, 'support', 'New dispute',
         'A dispute was opened on order ' || v_order.order_number || '.',
         jsonb_build_object('event', 'dispute_opened', 'dispute_id', v_row.id::text,
           'order_id', p_order_id::text, 'route', '/disputes/' || v_row.id::text)
  from public.profiles p
  join public.profile_roles pr on pr.profile_id = p.id
  join public.roles r on r.id = pr.role_id and r.name = 'admin'
  where p.deleted_at is null and p.id <> v_profile;

  return v_row;
end;
$function$;

-- Opener withdraws ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.withdraw_dispute(p_dispute_id uuid)
RETURNS public.disputes
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_row public.disputes;
begin
  update public.disputes set status = 'withdrawn'
  where id = p_dispute_id and opened_by = current_profile_id() and status = 'open'
  returning * into v_row;
  if not found then raise exception 'This dispute can no longer be withdrawn.'; end if;
  return v_row;
end;
$function$;

-- Admin resolves ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_dispute(
  p_dispute_id uuid, p_resolution text,
  p_refund_amount numeric DEFAULT NULL, p_note text DEFAULT NULL)
RETURNS public.disputes
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_row public.disputes; v_order public.orders; v_amount numeric(12,2);
begin
  if not has_role('admin') then
    raise exception 'Only an administrator can resolve disputes.' using errcode = '42501';
  end if;
  select * into v_row from public.disputes where id = p_dispute_id for update;
  if not found then raise exception 'Dispute not found.'; end if;
  if v_row.status <> 'open' then raise exception 'This dispute is already closed.'; end if;
  select * into v_order from public.orders where id = v_row.order_id;

  v_amount := case p_resolution
    when 'refund_full' then v_order.grand_total
    when 'refund_partial' then p_refund_amount
    else null end;
  if p_resolution = 'refund_partial'
     and (v_amount is null or v_amount <= 0 or v_amount >= v_order.grand_total) then
    raise exception 'A partial refund must be more than 0 and less than the order total.';
  end if;
  if nullif(btrim(p_note), '') is null then
    raise exception 'Please add a resolution note for both parties.';
  end if;

  update public.disputes
  set status = 'resolved', resolution = p_resolution, refund_amount = v_amount,
      resolution_note = btrim(p_note), resolved_by = current_profile_id(), resolved_at = now()
  where id = p_dispute_id
  returning * into v_row;

  if p_resolution = 'refund_full' then
    update public.payments set status = 'refunded' where order_id = v_order.id and deleted_at is null;
    update public.orders set payment_status = 'refunded' where id = v_order.id;
    insert into public.order_status_history (order_id, status, changed_by, notes)
    values (v_order.id, 'refunded', current_profile_id(), 'Dispute resolved: full refund.');
  elsif p_resolution = 'refund_partial' then
    update public.payments set status = 'partially_refunded' where order_id = v_order.id and deleted_at is null;
    update public.orders set payment_status = 'partially_refunded' where id = v_order.id;
  end if;

  insert into public.notifications(profile_id, type, title, body, data)
  select p.pid, 'support', 'Dispute resolved',
         'The dispute on order ' || v_order.order_number || ' was resolved.',
         jsonb_build_object('event', 'dispute_resolved', 'dispute_id', v_row.id::text,
           'order_id', v_order.id::text, 'resolution', p_resolution,
           'route', '/disputes/' || v_row.id::text)
  from (
    select v_order.profile_id as pid
    union
    select sp.profile_id from public.order_items oi
      join public.seller_profiles sp on sp.id = oi.seller_id and sp.deleted_at is null
      where oi.order_id = v_order.id
  ) p;
  return v_row;
end;
$function$;

REVOKE ALL ON FUNCTION public.open_dispute(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.withdraw_dispute(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resolve_dispute(uuid, text, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.open_dispute(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.withdraw_dispute(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_dispute(uuid, text, numeric, text) TO authenticated;

-- Evidence storage (private) -------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('dispute-evidence', 'dispute-evidence', false)
ON CONFLICT (id) DO NOTHING;

-- Text comparison (no ::uuid cast): policies on storage.objects are evaluated
-- for every bucket and AND order isn't guaranteed, so a cast could error on
-- other buckets' paths.
CREATE OR REPLACE FUNCTION public.can_access_dispute_folder(p_folder text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.disputes d
                 WHERE d.id::text = p_folder
                   AND public.is_dispute_participant(d.id));
$$;
REVOKE ALL ON FUNCTION public.can_access_dispute_folder(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_access_dispute_folder(text) TO authenticated;

CREATE POLICY dispute_evidence_participant_read ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'dispute-evidence'
         AND public.can_access_dispute_folder((storage.foldername(name))[1]));

CREATE POLICY dispute_evidence_participant_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'dispute-evidence'
              AND public.can_access_dispute_folder((storage.foldername(name))[1]));

-- support_tickets owner guard -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_support_ticket_owner_fields()
RETURNS trigger
LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null or has_role('admin') then return NEW; end if;
  if TG_OP = 'INSERT' then
    NEW.assigned_to := null;
    NEW.status := 'open';
    NEW.closed_at := null;
  else
    NEW.assigned_to := OLD.assigned_to;
    NEW.priority := OLD.priority;
    -- The owner may only close their own ticket.
    if NEW.status is distinct from OLD.status and NEW.status <> 'closed' then
      NEW.status := OLD.status;
    end if;
  end if;
  return NEW;
end;
$function$;
CREATE TRIGGER support_tickets_owner_fields_guard
  BEFORE INSERT OR UPDATE ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.enforce_support_ticket_owner_fields();
