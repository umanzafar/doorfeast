-- DoorFeast — Migration 21: real discount codes (promotions)
-- Run after migration_20. Documented in CLAUDE.md section 5 as Phase 2,
-- built now at the owner's request instead of a decorative deals banner
-- with nothing behind it. Restaurant owners can create their own
-- restaurant-funded codes from dashboard.html; platform-funded codes
-- (restaurant_id null) are schema-ready but have no admin UI yet.
--
-- IMPORTANT: order creation (CLAUDE.md Step 5) doesn't exist yet, so a
-- discount applied in restaurant.html's basket is only a client-side
-- estimate for now — nothing recalculates or enforces it server-side
-- until create-order lands. usage_limit / per_customer_limit /
-- first_order_only are stored but NOT enforced yet, since that requires
-- promotion_uses to actually be written by a real order flow. Don't
-- treat those three as working limits until Step 5 is built.

create table promotions (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null,
  type               text not null check (type in ('percent', 'fixed', 'free_delivery')),
  value              integer not null default 0, -- percent: whole number 1-100. fixed: pence. free_delivery: ignored.
  min_order_pence    integer,
  max_discount_pence integer,
  funded_by          text not null check (funded_by in ('platform', 'restaurant')),
  restaurant_id      uuid references restaurants(id) on delete cascade,
  starts_at          timestamptz,
  ends_at            timestamptz,
  usage_limit        integer,
  per_customer_limit integer,
  first_order_only   boolean not null default false,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  check (
    (funded_by = 'platform' and restaurant_id is null) or
    (funded_by = 'restaurant' and restaurant_id is not null)
  )
);

-- Codes only need to be unique per restaurant (platform codes globally
-- unique among themselves) — two different restaurants can both run "SAVE10".
create unique index promotions_restaurant_code_idx
  on promotions (restaurant_id, lower(code));

create table promotion_uses (
  id             uuid primary key default gen_random_uuid(),
  promotion_id   uuid not null references promotions(id) on delete cascade,
  order_id       uuid not null references orders(id),
  customer_id    uuid references customers(id),
  discount_pence integer not null,
  used_at        timestamptz not null default now()
);

alter table promotions     enable row level security;
alter table promotion_uses enable row level security;

-- Anyone can read an active, in-date promotion for a live restaurant (or a
-- platform-wide one) — needed so restaurant.html can look up a typed-in
-- code and show the "Available deals" banner. This does not leak private
-- data; discount codes are meant to be shareable.
create policy "public reads active promotions"
  on promotions for select
  using (
    is_active = true
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
    and (
      funded_by = 'platform'
      or exists (select 1 from restaurants r where r.id = promotions.restaurant_id and r.is_live = true)
    )
  );

create policy "owner can manage own restaurant promotions"
  on promotions for all
  using (
    exists (select 1 from restaurants r where r.id = promotions.restaurant_id and r.owner_user_id = auth.uid())
  )
  with check (
    funded_by = 'restaurant'
    and exists (select 1 from restaurants r where r.id = promotions.restaurant_id and r.owner_user_id = auth.uid())
  );

create policy "admins can manage all promotions"
  on promotions for all
  using (exists (select 1 from admins a where a.user_id = auth.uid()))
  with check (exists (select 1 from admins a where a.user_id = auth.uid()));

-- promotion_uses stays fully locked — nothing writes to it yet since
-- create-order doesn't exist. Revisit RLS here when Step 5 lands.
