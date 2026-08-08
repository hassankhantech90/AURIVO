-- Avatar storage bucket and object-level RLS.
--
-- Avatars are stored at `{profile_id}/avatar.jpg` inside the public `avatars`
-- bucket. Ownership is resolved server-side from public.profiles via
-- public.current_profile_id() (SECURITY DEFINER, keyed on auth.uid()), so a
-- client cannot write to another user's folder by changing the path.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

-- Public read, limited to the avatars bucket only.
drop policy if exists avatars_public_read on storage.objects;
create policy avatars_public_read
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'avatars');

-- Upload only inside the caller's own profile folder.
drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = public.current_profile_id()::text
);

-- Replace/update only the caller's own avatar.
drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = public.current_profile_id()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = public.current_profile_id()::text
);

-- Delete only the caller's own avatar.
drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = public.current_profile_id()::text
);
