-- DoorFeast — Migration 10: fix a real RLS bug in storage policies
--
-- Bug: policies on menu-photos and restaurant-logos wrote
--   (storage.foldername(name))[1] = r.id::text
-- inside a subquery that also selects FROM restaurants r. Since
-- restaurants has its own `name` column (the business name), Postgres
-- resolved the unqualified `name` to restaurants.name instead of the
-- uploaded object's path — so the check could never match, and every
-- upload was rejected with "new row violates row-level security
-- policy". Fix: qualify it as objects.name so it unambiguously refers
-- to the row being inserted/updated/deleted on storage.objects.

drop policy "owner can upload own menu photos" on storage.objects;
drop policy "owner can update own menu photos" on storage.objects;
drop policy "owner can delete own menu photos" on storage.objects;

create policy "owner can upload own menu photos"
  on storage.objects for insert
  with check (
    bucket_id = 'menu-photos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(objects.name))[1] = r.id::text
    )
  );

create policy "owner can update own menu photos"
  on storage.objects for update
  using (
    bucket_id = 'menu-photos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(objects.name))[1] = r.id::text
    )
  );

create policy "owner can delete own menu photos"
  on storage.objects for delete
  using (
    bucket_id = 'menu-photos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(objects.name))[1] = r.id::text
    )
  );

drop policy "owner can upload own restaurant logo" on storage.objects;
drop policy "owner can update own restaurant logo" on storage.objects;
drop policy "owner can delete own restaurant logo" on storage.objects;

create policy "owner can upload own restaurant logo"
  on storage.objects for insert
  with check (
    bucket_id = 'restaurant-logos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(objects.name))[1] = r.id::text
    )
  );

create policy "owner can update own restaurant logo"
  on storage.objects for update
  using (
    bucket_id = 'restaurant-logos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(objects.name))[1] = r.id::text
    )
  );

create policy "owner can delete own restaurant logo"
  on storage.objects for delete
  using (
    bucket_id = 'restaurant-logos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(objects.name))[1] = r.id::text
    )
  );
