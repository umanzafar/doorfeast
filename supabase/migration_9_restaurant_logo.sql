-- DoorFeast — Migration 9: restaurant logo upload
-- Run after migration_8. Same pattern as customer-avatars (migration_5):
-- public bucket (logos need to be viewable by customers eventually too),
-- owner-only upload/update/delete via RLS.

alter table restaurants add column logo_url text;

insert into storage.buckets (id, name, public)
values ('restaurant-logos', 'restaurant-logos', true)
on conflict (id) do nothing;

-- Files are stored at {restaurant_id}/{filename}, checked against the
-- owner_user_id of that restaurant.
create policy "anyone can view restaurant logos"
  on storage.objects for select
  using (bucket_id = 'restaurant-logos');

create policy "owner can upload own restaurant logo"
  on storage.objects for insert
  with check (
    bucket_id = 'restaurant-logos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = r.id::text
    )
  );

create policy "owner can update own restaurant logo"
  on storage.objects for update
  using (
    bucket_id = 'restaurant-logos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = r.id::text
    )
  );

create policy "owner can delete own restaurant logo"
  on storage.objects for delete
  using (
    bucket_id = 'restaurant-logos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = r.id::text
    )
  );
