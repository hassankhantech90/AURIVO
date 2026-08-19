-- Phase 14B — Chat messaging enablement.
-- Applied live as migration 16_chat_messaging.
--
-- Two SECURITY DEFINER RPCs (hardened search_path) close the user-facing gaps
-- without loosening RLS; a trigger maintains last_message_at; realtime is
-- enabled idempotently. Participant send/read stays governed by the existing
-- messages_participant_* / *_participant_select policies. No new user policies.

-- 1) Start (or reuse) a conversation. The counterpart is DERIVED from context —
--    never an arbitrary profile_id. Concurrency-safe (advisory xact lock),
--    idempotent find-or-create scoped to EXACTLY the buyer<->seller pair.
create or replace function public.start_conversation(
  p_seller_profile_id uuid,
  p_order_id uuid default null,
  p_rfq_id uuid default null
) returns uuid
language plpgsql security definer set search_path to 'public','pg_temp' as $body$
declare
  v_caller uuid := current_profile_id();
  v_seller_owner uuid;
  v_buyer uuid;
  v_type text;
  v_subject text;
  v_conv uuid;
begin
  if v_caller is null then raise exception 'Authentication required.'; end if;
  if p_order_id is not null and p_rfq_id is not null then
    raise exception 'Provide either an order or RFQ context, not both.';
  end if;

  select profile_id, store_name into v_seller_owner, v_subject
  from public.seller_profiles where id = p_seller_profile_id and deleted_at is null;
  if v_seller_owner is null then raise exception 'Seller not found.'; end if;

  if p_order_id is not null then
    select profile_id into v_buyer from public.orders where id = p_order_id and deleted_at is null;
    if v_buyer is null then raise exception 'Order not found.'; end if;
    if not exists (select 1 from public.order_items
                   where order_id = p_order_id and seller_id = p_seller_profile_id) then
      raise exception 'This seller has no items in that order.';
    end if;
    v_type := 'order';
  elsif p_rfq_id is not null then
    select buyer_profile_id into v_buyer from public.rfqs
      where id = p_rfq_id and deleted_at is null and seller_profile_id = p_seller_profile_id;
    if v_buyer is null then raise exception 'RFQ not found for this seller.'; end if;
    v_type := 'rfq';
  else
    if not exists (select 1 from public.seller_profiles
                   where id = p_seller_profile_id and verification_status = 'verified' and deleted_at is null) then
      raise exception 'You can only message verified stores.';
    end if;
    v_buyer := v_caller;
    v_type := 'buyer_seller';
  end if;

  if v_caller <> v_buyer and v_caller <> v_seller_owner then
    raise exception 'Not authorized to start this conversation.';
  end if;
  if v_buyer = v_seller_owner then
    raise exception 'Cannot start a conversation with yourself.';
  end if;

  -- Concurrency guard: serialize concurrent starts for the same context + pair.
  perform pg_advisory_xact_lock(
    hashtextextended(
      v_type || '|' || coalesce(p_order_id::text, '') || '|' || coalesce(p_rfq_id::text, '')
        || '|' || least(v_buyer::text, v_seller_owner::text)
        || '|' || greatest(v_buyer::text, v_seller_owner::text), 0));

  -- Reuse an existing conversation for the same context that is EXACTLY this pair.
  select c.id into v_conv
  from public.conversations c
  where c.deleted_at is null
    and c.conversation_type = v_type
    and c.order_id is not distinct from p_order_id
    and c.rfq_id is not distinct from p_rfq_id
    and public.is_conversation_participant(c.id, v_buyer)
    and public.is_conversation_participant(c.id, v_seller_owner)
    and (select count(*) from public.conversation_participants cp
         where cp.conversation_id = c.id and cp.left_at is null) = 2
  limit 1;
  if v_conv is not null then return v_conv; end if;

  insert into public.conversations(conversation_type, subject, order_id, rfq_id)
  values (v_type, v_subject, p_order_id, p_rfq_id) returning id into v_conv;
  insert into public.conversation_participants(conversation_id, profile_id, role)
  values (v_conv, v_buyer, 'buyer'), (v_conv, v_seller_owner, 'seller');
  return v_conv;
end $body$;

-- 2) Mark a conversation read — updates ONLY the caller's own participant row.
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql security definer set search_path to 'public','pg_temp' as $body$
declare v_caller uuid := current_profile_id();
begin
  if v_caller is null then raise exception 'Authentication required.'; end if;
  if not public.is_conversation_participant(p_conversation_id, v_caller) then
    raise exception 'Not a participant of this conversation.';
  end if;
  update public.conversation_participants
    set last_read_at = now()
    where conversation_id = p_conversation_id and profile_id = v_caller;
end $body$;

-- 3) Maintain conversations.last_message_at on new messages.
create or replace function public.touch_conversation_last_message()
returns trigger
language plpgsql security definer set search_path to 'public','pg_temp' as $body$
begin
  update public.conversations
    set last_message_at = NEW.created_at, updated_at = now()
    where id = NEW.conversation_id;
  return NEW;
end $body$;

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation
  after insert on public.messages
  for each row execute function public.touch_conversation_last_message();

-- 4) Enable realtime idempotently (ALTER PUBLICATION has no IF NOT EXISTS).
do $realtime$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations') then
    alter publication supabase_realtime add table public.conversations;
  end if;
end $realtime$;

-- 5) Grants
revoke all on function public.start_conversation(uuid, uuid, uuid) from public;
grant execute on function public.start_conversation(uuid, uuid, uuid) to authenticated;
revoke all on function public.mark_conversation_read(uuid) from public;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
