-- DoorFeast — Migration 5: customer profile pictures
-- Run after migration_4. Adds an avatar_url column to customers and a
-- public storage bucket for the photos (public because avatars need to
-- be viewable in the UI; upload/change/delete stays owner-only).

alter table customers add column avatar_url text;

insert into storage.buckets (id, name, public)
values ('customer-avatars', 'customer-avatars', true)
on conflict (id) do nothing;

-- Files are stored at {user_id}/{filename}, so the first path segment
-- is checked against the uploader's own auth id.
create policy "anyone can view customer avatars"
  on storage.objects for select
  using (bucket_id = 'customer-avatars');

create policy "customer can upload own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'customer-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "customer can update own avatar"
  on storage.objects for update
  using (
    bucket_id = 'customer-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "customer can delete own avatar"
  on storage.objects for delete
  using (
    bucket_id = 'customer-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
