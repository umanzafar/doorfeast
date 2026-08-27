-- DoorFeast — Migration 20: customer favourites
-- Run after migration_19. Customer accounts already exist (migration_3),
-- so this is real: a customer can save/unsave a restaurant from
-- restaurant.html, and see the list in customer/portal.html.

create table customer_favorites (
  id             uuid primary key default gen_random_uuid(),
  customer_id    uuid not null references customers(id) on delete cascade,
  restaurant_id  uuid not null references restaurants(id) on delete cascade,
  created_at     timestamptz not null default now(),
  unique (customer_id, restaurant_id)
);

alter table customer_favorites enable row level security;

create policy "customer can manage own favorites"
  on customer_favorites for all
  using (
    exists (select 1 from customers c where c.id = customer_favorites.customer_id and c.user_id = auth.uid())
  )
  with check (
    exists (select 1 from customers c where c.id = customer_favorites.customer_id and c.user_id = auth.uid())
  );
