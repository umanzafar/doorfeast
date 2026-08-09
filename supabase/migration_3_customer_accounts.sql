-- DoorFeast — Migration 3: customer accounts
-- Run this in the SQL Editor after migration_2. Adds real customer
-- accounts (signup/login/profile/order history), ahead of the normal
-- build order (CLAUDE.md lists this as Phase 2, after checkout/payments)
-- per explicit request — orders.customer_id stays nullable so guest
-- checkout keeps working once Step 5 (Stripe checkout) is built.

-- ============================================================
-- customers
-- ============================================================
create table customers (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null unique references auth.users(id),
  name                  text not null,
  email                 text not null,
  phone                 text,
  marketing_opt_in      boolean not null default false,
  credit_balance_pence  integer not null default 0,
  referral_code         text,
  referred_by           uuid references customers(id),
  created_at            timestamptz not null default now()
);

alter table customers enable row level security;

create policy "customer can insert own row"
  on customers for insert
  with check (user_id = auth.uid());

create policy "customer can read own row"
  on customers for select
  using (user_id = auth.uid());

create policy "customer can update own row"
  on customers for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- customer_addresses
-- ============================================================
create table customer_addresses (
  id             uuid primary key default gen_random_uuid(),
  customer_id    uuid not null references customers(id) on delete cascade,
  label          text,
  line1          text not null,
  line2          text,
  city           text not null,
  postcode       text not null,
  lat            double precision,
  lng            double precision,
  delivery_notes text,
  is_default     boolean not null default false,
  created_at     timestamptz not null default now()
);

alter table customer_addresses enable row level security;

create policy "customer can manage own addresses"
  on customer_addresses for all
  using (
    exists (select 1 from customers c where c.id = customer_addresses.customer_id and c.user_id = auth.uid())
  )
  with check (
    exists (select 1 from customers c where c.id = customer_addresses.customer_id and c.user_id = auth.uid())
  );

-- ============================================================
-- orders: link to customers (nullable — guest checkout still works)
-- ============================================================
alter table orders add column if not exists customer_id uuid references customers(id);

create policy "customer can read own orders"
  on orders for select
  using (
    exists (select 1 from customers c where c.id = orders.customer_id and c.user_id = auth.uid())
  );
