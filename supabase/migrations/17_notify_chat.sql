-- Phase 13C / migration 17 — chat-message notifications.
-- Applied live as migration 17_notify_chat.
--
-- A SECURITY DEFINER AFTER INSERT trigger on public.messages fans each message
-- out to every other active participant of the conversation. It coalesces to
-- one UNREAD notification per recipient+conversation by mutating ONLY data
-- (last_message_id / last_message_created_at / unread_count); the row's
-- created_at, title and body stay stable (no updated_at column exists, and
-- created_at is treated as the original-creation timestamp).
--
-- Concurrency: a pg_advisory_xact_lock keyed on the conversation serializes
-- notification generation per conversation, so the "one unread per
-- recipient+conversation" invariant holds even under concurrent inserts
-- (mirrors migration 16's find-or-create locking).
--
-- Suppression: sender is never notified; participants who have left (left_at)
-- or are soft-deleted (profiles.deleted_at) are excluded; a participant already
-- caught up (last_read_at >= message time) is skipped (best-effort — 14B
-- markRead runs after send, so this is a bonus on top of coalescing, not the
-- primary flood-control).
--
-- RLS unchanged. notifications is intentionally NOT added to supabase_realtime
-- (13A behavior preserved; the bell picks these up on the next load). Works
-- uniformly across buyer_seller / order / rfq / support conversation types.
-- Migrations 15 and 16 are untouched.

create or replace function public.notify_chat_message()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $b$
declare v_subject text;
begin
  perform pg_advisory_xact_lock(hashtextextended('chat_notif:'||NEW.conversation_id::text, 0));

  select subject into v_subject from public.conversations where id = NEW.conversation_id;

  update public.notifications n
     set data = n.data || jsonb_build_object(
                  'last_message_id', NEW.id::text,
                  'last_message_created_at', NEW.created_at,
                  'unread_count', coalesce((n.data->>'unread_count')::int,1)+1)
    from public.conversation_participants cp
    join public.profiles p on p.id = cp.profile_id and p.deleted_at is null
   where n.profile_id = cp.profile_id and n.type='chat_message'
     and n.data->>'conversation_id' = NEW.conversation_id::text and n.read_at is null
     and cp.conversation_id = NEW.conversation_id and cp.profile_id <> NEW.sender_profile_id
     and cp.left_at is null and (cp.last_read_at is null or cp.last_read_at < NEW.created_at);

  insert into public.notifications(profile_id, type, title, body, data)
  select cp.profile_id, 'chat_message', 'New message',
         coalesce('New message from '||nullif(v_subject,''), 'You have a new message.'),
         jsonb_build_object('event','chat_message',
           'conversation_id', NEW.conversation_id::text,
           'route', '/messages/'||NEW.conversation_id::text,
           'last_message_id', NEW.id::text,
           'last_message_created_at', NEW.created_at,
           'unread_count', 1)
  from public.conversation_participants cp
  join public.profiles p on p.id = cp.profile_id and p.deleted_at is null
  where cp.conversation_id = NEW.conversation_id and cp.profile_id <> NEW.sender_profile_id
    and cp.left_at is null and (cp.last_read_at is null or cp.last_read_at < NEW.created_at)
    and not exists (select 1 from public.notifications n2
                    where n2.profile_id = cp.profile_id and n2.type='chat_message'
                      and n2.data->>'conversation_id' = NEW.conversation_id::text
                      and n2.read_at is null);
  return NEW;
end $b$;

drop trigger if exists messages_notify_participants on public.messages;
create trigger messages_notify_participants after insert on public.messages
  for each row execute function public.notify_chat_message();
