-- DoorFeast — Migration 13: restaurant cover photo
-- Run after migration_12. Same pattern as restaurant-logos (migration_9):
-- public bucket, owner-only upload/update/delete via RLS.

alter table restaurants add column cover_url text;

insert into storage.buckets (id, name, public)
values ('restaurant-covers', 'restaurant-covers', true)
on conflict (id) do nothing;

create policy "anyone can view restaurant covers"
  on storage.objects for select
  using (bucket_id = 'restaurant-covers');

create policy "owner can upload own restaurant cover"
  on storage.objects for insert
  with check (
    bucket_id = 'restaurant-covers'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(objects.name))[1] = r.id::text
    )
  );

create policy "owner can update own restaurant cover"
  on storage.objects for update
  using (
    bucket_id = 'restaurant-covers'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(objects.name))[1] = r.id::text
    )
  );

create policy "owner can delete own restaurant cover"
  on storage.objects for delete
  using (
    bucket_id = 'restaurant-covers'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(objects.name))[1] = r.id::text
    )
  );
