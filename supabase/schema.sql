-- DoorFeast — Step 1 Supabase schema
-- Run this once in a new Supabase project: Dashboard > SQL Editor > New query > paste > Run.
-- Tables are created in the order CLAUDE.md specifies. RLS is ON for every table.

create extension if not exists pgcrypto;

-- ============================================================
-- restaurants
-- ============================================================
create table restaurants (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  slug                 text not null unique,
  address              text not null,
  postcode             text not null,
  phone                text not null,
  cuisine              text not null,
  is_live              boolean not null default false,
  does_delivery        boolean not null default false,
  does_collection      boolean not null default false,
  delivery_fee_pence   integer,
  min_order_pence      integer,
  delivery_postcodes   text[],
  opening_hours        jsonb,
  stripe_account_id    text,
  created_at           timestamptz not null default now()
);

-- ============================================================
-- menu_categories
-- ============================================================
create table menu_categories (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references restaurants(id) on delete cascade,
  name           text not null,
  sort_order     integer not null default 0
);

-- ============================================================
-- menu_items
-- ============================================================
create table menu_items (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references restaurants(id) on delete cascade,
  category_id    uuid not null references menu_categories(id) on delete cascade,
  name           text not null,
  description    text,
  price_pence    integer not null check (price_pence >= 0),
  allergens      text[] not null check (array_length(allergens, 1) > 0),
  is_available   boolean not null default true,
  photo_url      text,
  sort_order     integer not null default 0
);

-- ============================================================
-- orders
-- ============================================================
create table orders (
  id                          uuid primary key default gen_random_uuid(),
  order_number                text not null unique,
  restaurant_id               uuid not null references restaurants(id),
  customer_name                text not null,
  customer_phone               text not null,
  customer_email                text not null,
  order_type                  text not null check (order_type in ('collection', 'delivery')),
  delivery_address             text,
  subtotal_pence               integer not null,
  delivery_fee_pence           integer not null default 0,
  total_pence                  integer not null,
  commission_pence             integer not null,
  status                       text not null default 'pending_payment'
                                check (status in ('pending_payment','paid','accepted','preparing','ready','completed','rejected','refunded')),
  payment_status                text not null default 'pending'
                                check (payment_status in ('pending','paid','failed','refunded')),
  stripe_payment_intent_id      text,
  customer_note                 text,
  created_at                    timestamptz not null default now(),
  accepted_at                   timestamptz,
  ready_at                      timestamptz
);

-- ============================================================
-- order_items
-- ============================================================
create table order_items (
  id                 uuid primary key default gen_random_uuid(),
  order_id           uuid not null references orders(id) on delete cascade,
  menu_item_id       uuid not null references menu_items(id),
  item_name          text not null,
  item_price_pence   integer not null,
  quantity           integer not null check (quantity > 0),
  line_total_pence   integer not null
);

-- ============================================================
-- Row Level Security
-- ============================================================
-- Every table below is locked by default. The only public (anon key)
-- access granted is READ-ONLY, and only for data customers need to
-- browse a live restaurant's menu. Every write in V1 goes through
-- /api functions using the service_role key, which bypasses RLS —
-- so no anon INSERT/UPDATE/DELETE policy exists on any table.

alter table restaurants     enable row level security;
alter table menu_categories enable row level security;
alter table menu_items      enable row level security;
alter table orders          enable row level security;
alter table order_items     enable row level security;

-- restaurants: public can read only restaurants that are live
create policy "public can read live restaurants"
  on restaurants for select
  using (is_live = true);

-- menu_categories: public can read categories belonging to a live restaurant
create policy "public can read categories of live restaurants"
  on menu_categories for select
  using (
    exists (
      select 1 from restaurants r
      where r.id = menu_categories.restaurant_id
        and r.is_live = true
    )
  );

-- menu_items: public can read items belonging to a live restaurant
-- (includes unavailable items — the frontend greys them out, per Step 3)
create policy "public can read items of live restaurants"
  on menu_items for select
  using (
    exists (
      select 1 from restaurants r
      where r.id = menu_items.restaurant_id
        and r.is_live = true
    )
  );

-- orders: no anon policy. Nobody can read or write orders via the anon key.
-- Order creation happens only in /api/create-order (service_role).
-- Order status updates happen only in /api/stripe-webhook (service_role).
-- The restaurant order inbox (Step 6) needs its own access decision —
-- not resolved yet, see note below.

-- order_items: same as orders — no anon policy, service_role only.

-- ============================================================
-- OPEN DECISION — restaurant order inbox access (Step 6)
-- ============================================================
-- CLAUDE.md's V1 scope excludes staff accounts, so there's no login
-- system yet for the POS tablet that will run the order inbox. Until
-- that's decided, orders/order_items stay fully locked to service_role.
-- The order inbox will need either:
--   (a) a simple Supabase Auth login per restaurant + a policy scoping
--       orders to that restaurant, or
--   (b) a server-side API route (using service_role) that the tablet
--       page calls instead of querying Supabase directly.
-- Don't add a workaround for this without asking first.
