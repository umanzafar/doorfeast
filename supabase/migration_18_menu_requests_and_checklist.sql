-- DoorFeast — Migration 18: menu-build requests + go-live checklist
-- Run after migration_17.

-- ============================================================
-- menu_build_requests — hybrid menu-building intake. Owner uploads
-- photos of their menu from dashboard.html instead of typing every item
-- in themselves; a human on the team builds it from the photos and marks
-- the request done from admin.html's Menu Requests tab.
-- ============================================================
create table menu_build_requests (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references restaurants(id),
  file_paths    text[] not null,
  note          text,
  status        text not null default 'pending' check (status in ('pending','in_progress','done')),
  created_at    timestamptz not null default now()
);
alter table menu_build_requests enable row level security;

create policy "owner can insert own requests"
  on menu_build_requests for insert
  with check (exists (select 1 from restaurants r where r.id = restaurant_id and r.owner_user_id = auth.uid()));

create policy "owner can read own requests"
  on menu_build_requests for select
  using (exists (select 1 from restaurants r where r.id = restaurant_id and r.owner_user_id = auth.uid()));

create policy "admins can read and update all requests"
  on menu_build_requests for all
  using (exists (select 1 from admins a where a.user_id = auth.uid()));

-- menu-build-uploads: private bucket, same convention as
-- application-documents — files stored at {user_id}/{filename}, owner can
-- upload/read their own prefix, admins can read all.
create policy "owner can upload own menu build files"
  on storage.objects for insert
  with check (
    bucket_id = 'menu-build-uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "owner and admins can read menu build files"
  on storage.objects for select
  using (
    bucket_id = 'menu-build-uploads'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (select 1 from admins a where a.user_id = auth.uid())
    )
  );

-- ============================================================
-- Go-live checklist. Menu loaded and hours set are already knowable from
-- existing data; documents verified is already covered by the
-- dashboard.html gate fix. These 3 need a manual admin confirmation since
-- there's no automated way to check them yet (Stripe Connect isn't
-- integrated, no device-registration or test-order feature exists).
-- ============================================================
alter table restaurants add column checklist_stripe_connected boolean not null default false;
alter table restaurants add column checklist_device_registered boolean not null default false;
alter table restaurants add column checklist_test_order_completed boolean not null default false;

-- Owners already have broad UPDATE on their own restaurants row (business
-- info, hours, delivery settings) — this trigger stops that from also
-- letting them self-report the 3 checklist columns above. Same
-- defense-in-depth pattern as migration_14's order-field protection.
create or replace function protect_checklist_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from admins a where a.user_id = auth.uid()) then
    NEW.checklist_stripe_connected := OLD.checklist_stripe_connected;
    NEW.checklist_device_registered := OLD.checklist_device_registered;
    NEW.checklist_test_order_completed := OLD.checklist_test_order_completed;
  end if;
  return NEW;
end;
$$;

create trigger trg_protect_checklist_columns
before update on restaurants
for each row execute function protect_checklist_columns();

-- No admin UPDATE policy on restaurants existed before this — needed so
-- admins can actually tick the 3 checklist boxes from admin.html. The
-- trigger above is what stops a non-admin owner from using this same
-- broadened surface to write the checklist columns themselves.
create policy "admins can update any restaurant"
  on restaurants for update
  using (exists (select 1 from admins a where a.user_id = auth.uid()));
