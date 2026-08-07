-- DoorFeast — Migration 2: replaces Google Apps Script with Supabase
-- Run this in the SQL Editor after schema.sql (and after seed_fojis_ice_lounge.sql
-- if you've already run that). Adds: partner applications, admin allowlist,
-- waitlist signups, restaurant ownership + geo columns, and two Storage buckets.

-- ============================================================
-- restaurants: new columns
-- ============================================================
alter table restaurants add column owner_user_id uuid references auth.users(id);
alter table restaurants add column lat double precision;
alter table restaurants add column lng double precision;

-- ============================================================
-- restaurant_applications
-- ============================================================
create table restaurant_applications (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users(id),
  business_name       text not null,
  owner_name          text not null,
  phone               text not null,
  email               text not null,
  address             text not null,
  cuisine             text not null,
  hygiene_cert_path   text not null,
  business_reg_path   text not null,
  id_doc_path         text not null,
  status              text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reject_reason       text,
  restaurant_id       uuid references restaurants(id),
  created_at          timestamptz not null default now(),
  decided_at          timestamptz
);

-- ============================================================
-- admins
-- ============================================================
create table admins (
  user_id     uuid primary key references auth.users(id),
  created_at  timestamptz not null default now()
);

-- ============================================================
-- waitlist_signups
-- ============================================================
create table waitlist_signups (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  area        text,
  created_at  timestamptz not null default now()
);

-- ============================================================
-- RLS
-- ============================================================
alter table restaurant_applications enable row level security;
alter table admins                  enable row level security;
alter table waitlist_signups        enable row level security;

-- restaurant_applications: owner can insert/read their own; admins can read all.
-- No update policy at all — status changes only happen via the
-- decide-application Edge Function using service_role, never straight
-- from the browser (even an admin's browser session).
create policy "owner can insert own application"
  on restaurant_applications for insert
  with check (user_id = auth.uid());

create policy "owner can read own application"
  on restaurant_applications for select
  using (user_id = auth.uid());

create policy "admins can read all applications"
  on restaurant_applications for select
  using (exists (select 1 from admins a where a.user_id = auth.uid()));

-- admins: a user can check their own membership (used to show/hide admin UI).
-- This is a UI convenience only — real enforcement lives in RLS on the
-- other tables and inside the decide-application Edge Function.
create policy "user can check own admin status"
  on admins for select
  using (user_id = auth.uid());

-- waitlist_signups: anyone can sign up, nobody can read the list back out.
create policy "anyone can join waitlist"
  on waitlist_signups for insert
  with check (true);

-- ============================================================
-- restaurants / menu_categories / menu_items: extend read policies so an
-- owner can see their own restaurant/menu even before is_live = true, and
-- add owner-scoped write policies (this replaces the Menu Apps Script —
-- plain RLS-protected CRUD on the owner's own data, no Edge Function needed).
-- ============================================================

drop policy "public can read live restaurants" on restaurants;
create policy "public reads live restaurants, owner reads own"
  on restaurants for select
  using (is_live = true or owner_user_id = auth.uid());

create policy "owner can update own restaurant"
  on restaurants for update
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

drop policy "public can read categories of live restaurants" on menu_categories;
create policy "public reads categories of live restaurants, owner reads own"
  on menu_categories for select
  using (
    exists (
      select 1 from restaurants r
      where r.id = menu_categories.restaurant_id
        and (r.is_live = true or r.owner_user_id = auth.uid())
    )
  );

create policy "owner can manage own categories"
  on menu_categories for all
  using (
    exists (select 1 from restaurants r where r.id = menu_categories.restaurant_id and r.owner_user_id = auth.uid())
  )
  with check (
    exists (select 1 from restaurants r where r.id = menu_categories.restaurant_id and r.owner_user_id = auth.uid())
  );

drop policy "public can read items of live restaurants" on menu_items;
create policy "public reads items of live restaurants, owner reads own"
  on menu_items for select
  using (
    exists (
      select 1 from restaurants r
      where r.id = menu_items.restaurant_id
        and (r.is_live = true or r.owner_user_id = auth.uid())
    )
  );

create policy "owner can manage own items"
  on menu_items for all
  using (
    exists (select 1 from restaurants r where r.id = menu_items.restaurant_id and r.owner_user_id = auth.uid())
  )
  with check (
    exists (select 1 from restaurants r where r.id = menu_items.restaurant_id and r.owner_user_id = auth.uid())
  );

-- ============================================================
-- Storage buckets
-- ============================================================
insert into storage.buckets (id, name, public)
values ('application-documents', 'application-documents', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('menu-photos', 'menu-photos', true)
on conflict (id) do nothing;

-- application-documents: private. Files are stored at
-- {user_id}/{filename}, so the first path segment is checked against
-- the uploader's own id. Admins can read every applicant's documents.
create policy "owner can upload own application documents"
  on storage.objects for insert
  with check (
    bucket_id = 'application-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "owner and admins can read application documents"
  on storage.objects for select
  using (
    bucket_id = 'application-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (select 1 from admins a where a.user_id = auth.uid())
    )
  );

-- menu-photos: public read (needed for the menu to display), owner-only
-- write. Files are stored at {restaurant_id}/{filename}.
create policy "anyone can view menu photos"
  on storage.objects for select
  using (bucket_id = 'menu-photos');

create policy "owner can upload own menu photos"
  on storage.objects for insert
  with check (
    bucket_id = 'menu-photos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = r.id::text
    )
  );

create policy "owner can update own menu photos"
  on storage.objects for update
  using (
    bucket_id = 'menu-photos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = r.id::text
    )
  );

create policy "owner can delete own menu photos"
  on storage.objects for delete
  using (
    bucket_id = 'menu-photos'
    and exists (
      select 1 from restaurants r
      where r.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = r.id::text
    )
  );

-- ============================================================
-- After you (the founder) create your own account through the new
-- signup.html (Supabase Auth), run this once to make yourself an admin —
-- replace the email with the one you signed up with:
--
--   insert into admins (user_id)
--   select id from auth.users where email = 'YOUR_EMAIL_HERE';
--
-- Without this, admin.html will correctly refuse to show you anything.
-- ============================================================
