-- Phase 13C / migration 18 — notification coverage.
-- Applied live as migration 18_notify_coverage.
--
-- Four SECURITY DEFINER trigger functions (hardened search_path) extend
-- notification generation to the events Phases 14A/14B introduced plus two
-- seller-facing asymmetries. Recipients are always resolved server-side
-- (roles join / FK lookups); no client-supplied recipient ids. RLS unchanged;
-- notifications stays OUT of supabase_realtime (13A behavior preserved). The
-- data.route deep-links match the live Flutter routes. Migrations 15/16/17 are
-- untouched, and these coexist with migration 15's triggers on the same tables
-- (distinct recipients / events).
--
-- A. Support ticket created  -> admins (excluding an admin creator).
-- B. Support status/assignment change -> ticket owner / newly assigned admin.
-- C. Directed RFQ (seller_profile_id set) -> the targeted seller.
-- D. Order cancelled/refunded -> each affected seller once per order+status
--    (advisory xact lock keyed on order+status makes the fan-out dedup
--    concurrency-safe, mirroring migrations 16/17).

create or replace function public.notify_support_ticket_created()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
begin
  insert into public.notifications(profile_id, type, title, body, data)
  select a.id, 'support', 'New support ticket',
         'A new '||NEW.category||' ticket was submitted: '||NEW.subject,
         jsonb_build_object('event','ticket_created','ticket_id',NEW.id::text,
           'category',NEW.category,'route','/admin/support/'||NEW.id::text)
  from (select distinct p.id
        from public.profiles p
        join public.profile_roles pr on pr.profile_id = p.id
        join public.roles r on r.id = pr.role_id
        where r.name = 'admin' and p.deleted_at is null) a
  where a.id <> NEW.profile_id
    and not exists (select 1 from public.notifications n
                    where n.profile_id = a.id and n.type='support'
                      and n.data->>'ticket_id' = NEW.id::text
                      and n.data->>'event' = 'ticket_created');
  return NEW;
end $b$;

create or replace function public.notify_support_ticket_update()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
begin
  if NEW.status is distinct from OLD.status
     and exists (select 1 from public.profiles p where p.id = NEW.profile_id and p.deleted_at is null) then
    insert into public.notifications(profile_id, type, title, body, data)
    values (NEW.profile_id, 'support', 'Support ticket '||NEW.status,
      'Your ticket "'||NEW.subject||'" is now '||NEW.status||'.',
      jsonb_build_object('event','ticket_update','ticket_id',NEW.id::text,
        'status',NEW.status,'route','/support'));
  end if;
  if NEW.assigned_to is distinct from OLD.assigned_to and NEW.assigned_to is not null
     and NEW.assigned_to <> NEW.profile_id
     and exists (select 1 from public.profiles p where p.id = NEW.assigned_to and p.deleted_at is null) then
    insert into public.notifications(profile_id, type, title, body, data)
    values (NEW.assigned_to, 'support', 'Ticket assigned to you',
      'You were assigned ticket "'||NEW.subject||'".',
      jsonb_build_object('event','ticket_assigned','ticket_id',NEW.id::text,
        'route','/admin/support/'||NEW.id::text));
  end if;
  return NEW;
end $b$;

create or replace function public.notify_rfq_directed()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_seller uuid;
begin
  if NEW.seller_profile_id is null then return NEW; end if;
  select profile_id into v_seller from public.seller_profiles
    where id = NEW.seller_profile_id and deleted_at is null;
  if v_seller is null or v_seller = NEW.buyer_profile_id then return NEW; end if;
  insert into public.notifications(profile_id, type, title, body, data)
  select v_seller, 'seller_event', 'New quote request',
         'You received a request for quotation.',
         jsonb_build_object('event','rfq_received','rfq_id',NEW.id::text,
           'route','/seller-studio/rfqs/'||NEW.id::text)
  where not exists (select 1 from public.notifications n
                    where n.profile_id = v_seller and n.type='seller_event'
                      and n.data->>'rfq_id' = NEW.id::text
                      and n.data->>'event' = 'rfq_received');
  return NEW;
end $b$;

create or replace function public.notify_order_cancel_seller()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_number text;
begin
  if NEW.status not in ('cancelled','refunded') then return NEW; end if;
  perform pg_advisory_xact_lock(hashtextextended('order_cancel_notif:'||NEW.order_id::text||':'||NEW.status, 0));
  select order_number into v_number from public.orders where id = NEW.order_id;
  insert into public.notifications(profile_id, type, title, body, data)
  select s.profile_id, 'seller_event',
         case NEW.status when 'cancelled' then 'Order cancelled' else 'Order refunded' end,
         'Order '||coalesce(v_number,'')||' was '||NEW.status||'.',
         jsonb_build_object('event','order_cancelled_seller','order_id',NEW.order_id::text,
           'status',NEW.status,'route','/seller-studio/orders/'||NEW.order_id::text)
  from (select distinct sp.profile_id
        from public.order_items oi
        join public.seller_profiles sp on sp.id = oi.seller_id and sp.deleted_at is null
        where oi.order_id = NEW.order_id) s
  where not exists (select 1 from public.notifications n
                    where n.profile_id = s.profile_id and n.type='seller_event'
                      and n.data->>'order_id' = NEW.order_id::text
                      and n.data->>'event' = 'order_cancelled_seller'
                      and n.data->>'status' = NEW.status);
  return NEW;
end $b$;

drop trigger if exists support_tickets_notify_created on public.support_tickets;
create trigger support_tickets_notify_created after insert on public.support_tickets
  for each row execute function public.notify_support_ticket_created();

drop trigger if exists support_tickets_notify_update on public.support_tickets;
create trigger support_tickets_notify_update after update of status, assigned_to on public.support_tickets
  for each row execute function public.notify_support_ticket_update();

drop trigger if exists rfqs_notify_seller on public.rfqs;
create trigger rfqs_notify_seller after insert on public.rfqs
  for each row execute function public.notify_rfq_directed();

drop trigger if exists order_status_history_notify_seller_cancel on public.order_status_history;
create trigger order_status_history_notify_seller_cancel after insert on public.order_status_history
  for each row execute function public.notify_order_cancel_seller();
