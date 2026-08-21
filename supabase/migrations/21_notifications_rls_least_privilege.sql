-- Phase 13C hardening / migration 21 — least-privilege RLS + grants on
-- notifications. Applied live as migration 21_notifications_rls_least_privilege.
--
-- Notification generation is server-only: the SECURITY DEFINER triggers from
-- migrations 15/17/18/19 run with owner privileges and bypass RLS + role grants,
-- so removing the authenticated INSERT/DELETE paths does not affect generation.
-- The Flutter client only reads, marks read (read_at), and soft-deletes
-- (deleted_at). This migration therefore reduces authenticated access to:
--   SELECT  -> own rows (admins may also view others)
--   UPDATE  -> own rows only, columns read_at + deleted_at only
--   INSERT  -> none (server-only)
--   DELETE  -> none (client soft-deletes via update of deleted_at)
-- Row scope is enforced by the RLS policy; column scope by the column-level
-- grant. anon loses all direct access. notification_templates untouched;
-- notifications stays out of supabase_realtime; migrations 15-20 untouched.

drop policy if exists notifications_owner_all on public.notifications;

create policy notifications_select_own on public.notifications
  for select to authenticated
  using (profile_id = current_profile_id() or has_role('admin'));

create policy notifications_update_own on public.notifications
  for update to authenticated
  using (profile_id = current_profile_id())
  with check (profile_id = current_profile_id());

revoke insert, update, delete, truncate on public.notifications from authenticated;
revoke insert, update, delete, truncate, select on public.notifications from anon;
grant update (read_at, deleted_at) on public.notifications to authenticated;
