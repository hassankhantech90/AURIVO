-- Phase 13B — Server-side notification generation.
-- Applied live as migration 15_notification_generation.
--
-- Five SECURITY DEFINER trigger functions (hardened search_path) insert into
-- public.notifications with a server-resolved target profile_id. RLS unchanged;
-- checkout/buyer/seller flows untouched (notifications are a trigger side-effect).
-- Order-status notifies the buyer on key milestones only; new-order is deduped
-- per seller+order; verification/moderation fire only on real status transitions.
-- The data.route deep-link matches the in-app notification centre (Phase 13A).

create or replace function public.notify_order_status()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $body$
declare v_buyer uuid; v_number text; v_title text;
begin
  if NEW.status not in ('confirmed','shipped','delivered','cancelled','refunded') then return NEW; end if;
  select profile_id, order_number into v_buyer, v_number from public.orders where id = NEW.order_id;
  if v_buyer is null then return NEW; end if;
  v_title := case NEW.status
    when 'confirmed' then 'Order confirmed' when 'shipped' then 'Order shipped'
    when 'delivered' then 'Order delivered' when 'cancelled' then 'Order cancelled'
    else 'Order refunded' end;
  insert into public.notifications(profile_id, type, title, body, data)
  values (v_buyer, 'order_update', v_title,
    'Your order ' || v_number || ' is now ' || NEW.status || '.',
    jsonb_build_object('route', '/orders/' || NEW.order_id::text,
      'order_id', NEW.order_id::text, 'event', 'order_status', 'status', NEW.status));
  return NEW;
end $body$;

create or replace function public.notify_new_order_seller()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $body$
declare v_seller uuid; v_number text;
begin
  select profile_id into v_seller from public.seller_profiles where id = NEW.seller_id and deleted_at is null;
  if v_seller is null then return NEW; end if;
  if exists (select 1 from public.notifications
             where profile_id = v_seller
               and data->>'order_id' = NEW.order_id::text
               and data->>'event' = 'new_order') then
    return NEW;
  end if;
  select order_number into v_number from public.orders where id = NEW.order_id;
  insert into public.notifications(profile_id, type, title, body, data)
  values (v_seller, 'seller_event', 'New order',
    'You have a new order ' || coalesce(v_number, '') || ' to fulfil.',
    jsonb_build_object('route', '/seller-studio/orders/' || NEW.order_id::text,
      'order_id', NEW.order_id::text, 'event', 'new_order'));
  return NEW;
end $body$;

create or replace function public.notify_quote_received()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $body$
declare v_buyer uuid;
begin
  select buyer_profile_id into v_buyer from public.rfqs where id = NEW.rfq_id and deleted_at is null;
  if v_buyer is null then return NEW; end if;
  insert into public.notifications(profile_id, type, title, body, data)
  values (v_buyer, 'order_update', 'New quote received',
    'A seller responded to your request with a quote.',
    jsonb_build_object('route', '/wholesale/' || NEW.rfq_id::text,
      'rfq_id', NEW.rfq_id::text, 'event', 'quote_received'));
  return NEW;
end $body$;

create or replace function public.notify_seller_verification()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $body$
declare v_title text;
begin
  if NEW.verification_status is not distinct from OLD.verification_status then return NEW; end if;
  if NEW.verification_status not in ('verified','rejected','suspended') then return NEW; end if;
  v_title := case NEW.verification_status
    when 'verified' then 'Store verified'
    when 'rejected' then 'Store verification rejected'
    else 'Store suspended' end;
  insert into public.notifications(profile_id, type, title, body, data)
  values (NEW.profile_id, 'seller_event', v_title,
    'Your store status is now ' || NEW.verification_status || '.',
    jsonb_build_object('route', '/seller-studio/settings',
      'event', 'store_verification', 'status', NEW.verification_status));
  return NEW;
end $body$;

create or replace function public.notify_product_moderation()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $body$
declare v_seller uuid; v_title text;
begin
  if NEW.status is not distinct from OLD.status then return NEW; end if;
  if NEW.status not in ('approved','rejected') then return NEW; end if;
  select profile_id into v_seller from public.seller_profiles where id = NEW.seller_id and deleted_at is null;
  if v_seller is null then return NEW; end if;
  v_title := case NEW.status when 'approved' then 'Product approved' else 'Product rejected' end;
  insert into public.notifications(profile_id, type, title, body, data)
  values (v_seller, 'seller_event', v_title,
    '"' || NEW.title || '" was ' || NEW.status || '.',
    jsonb_build_object('route', '/seller-studio/edit/' || NEW.id::text,
      'product_id', NEW.id::text, 'event', 'product_moderation', 'status', NEW.status));
  return NEW;
end $body$;

drop trigger if exists order_status_history_notify on public.order_status_history;
create trigger order_status_history_notify after insert on public.order_status_history
  for each row execute function public.notify_order_status();

drop trigger if exists order_items_notify_seller on public.order_items;
create trigger order_items_notify_seller after insert on public.order_items
  for each row execute function public.notify_new_order_seller();

drop trigger if exists quotes_notify_buyer on public.quotes;
create trigger quotes_notify_buyer after insert on public.quotes
  for each row execute function public.notify_quote_received();

drop trigger if exists seller_profiles_notify_verification on public.seller_profiles;
create trigger seller_profiles_notify_verification after update of verification_status on public.seller_profiles
  for each row execute function public.notify_seller_verification();

drop trigger if exists products_notify_moderation on public.products;
create trigger products_notify_moderation after update of status on public.products
  for each row execute function public.notify_product_moderation();
