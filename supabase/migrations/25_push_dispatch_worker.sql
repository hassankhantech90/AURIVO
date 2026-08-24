-- Phase 22 / migration 25 — dedicated least-privilege push dispatch worker role
-- (P2 worker-auth, Tier 3). Applied live as migration 25_push_dispatch_worker.
--
-- The Edge Function connects through the Supavisor transaction pool AS
-- push_dispatch_worker. Tier 2 (custom push_worker JWT) was rejected because it
-- would depend on the legacy shared HS256 JWT secret.
--
-- The role can EXECUTE ONLY the three migration-24 worker RPCs and holds no
-- table privileges. A narrow PUBLIC-EXECUTE hardening removes the ambient reach
-- to unrelated SECURITY DEFINER functions; explicit anon/authenticated/
-- service_role grants already coexist on those functions, so existing RLS and
-- application behavior is unchanged (no re-grant required). Migrations 22-24 are
-- untouched.
--
-- NOTE: the role is created LOGIN with NO password here. The connection password
-- is set out-of-band (dashboard / ALTER ROLE) and stored only as an Edge Function
-- secret — never in this migration, source, or logs. CONNECT (database) and
-- USAGE (schema public) are already available to the role via PUBLIC and were
-- verified present, so no explicit grants are added.
--
-- Verified rolled-back (W1-W14): exact role attributes; CONNECT/USAGE present;
-- EXECUTE on exactly the 3 RPCs; no table privileges; no memberships (cannot SET
-- ROLE push_worker); BYPASSRLS false; cannot execute any unrelated SECURITY
-- DEFINER function; authenticated/anon retain is_conversation_participant; chat
-- RLS + triggers still fire; worker RPCs function under the role;
-- authenticated/anon/public still cannot execute the worker RPCs.

do $mig$
begin
  if not exists (select 1 from pg_roles where rolname='push_dispatch_worker') then
    create role push_dispatch_worker login noinherit nocreatedb nocreaterole nobypassrls noreplication;
  end if;
end $mig$;

grant execute on function public.claim_push_outbox(int,int)              to push_dispatch_worker;
grant execute on function public.report_push_results(uuid,uuid,jsonb)    to push_dispatch_worker;
grant execute on function public.requeue_stale_push(int)                 to push_dispatch_worker;

-- Narrow PUBLIC-execute hardening (behavior-preserving): block ambient reach to
-- unrelated SECURITY DEFINER functions. is_conversation_participant is the only
-- non-trigger one still PUBLIC-granted (its explicit authenticated/anon grants
-- persist, so the RLS policies that use it keep working); the rest are trigger
-- functions, which fire regardless of caller EXECUTE (proven by the existing
-- service_role-only trigger functions), so revoking PUBLIC is safe.
revoke execute on function public.is_conversation_participant(uuid,uuid)  from public;
revoke execute on function public.enqueue_push_outbox()                   from public;
revoke execute on function public.notify_chat_message()                   from public;
revoke execute on function public.notify_new_order_seller()               from public;
revoke execute on function public.notify_order_cancel_seller()            from public;
revoke execute on function public.notify_order_status()                   from public;
revoke execute on function public.notify_product_moderation()             from public;
revoke execute on function public.notify_product_review_approved()        from public;
revoke execute on function public.notify_quote_received()                 from public;
revoke execute on function public.notify_rfq_directed()                   from public;
revoke execute on function public.notify_seller_review_approved()         from public;
revoke execute on function public.notify_seller_verification()            from public;
revoke execute on function public.notify_support_ticket_created()         from public;
revoke execute on function public.notify_support_ticket_update()          from public;
revoke execute on function public.push_devices_on_profile_soft_delete()   from public;
revoke execute on function public.touch_conversation_last_message()       from public;