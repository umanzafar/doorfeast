-- DoorFeast — Migration 19: menu item option groups (sizes, extras)
-- Run after migration_18. Documented in CLAUDE.md section 5 but never
-- actually created — a pizza shop can't sell "Small/Medium/Large" or
-- "extra cheese" without this.

create table option_groups (
  id            uuid primary key default gen_random_uuid(),
  menu_item_id  uuid not null references menu_items(id) on delete cascade,
  name          text not null,
  is_required   boolean not null default false,
  min_choices   integer not null default 0,
  max_choices   integer not null default 1 check (max_choices >= 1),
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now()
);

create table option_choices (
  id                uuid primary key default gen_random_uuid(),
  option_group_id   uuid not null references option_groups(id) on delete cascade,
  name              text not null,
  price_delta_pence integer not null default 0,
  is_available      boolean not null default true,
  sort_order        integer not null default 0,
  created_at        timestamptz not null default now()
);

alter table option_groups  enable row level security;
alter table option_choices enable row level security;

-- Same read/write shape as menu_items (migration_2): public can read
-- groups/choices belonging to a live restaurant's items, an owner can
-- also read+write their own regardless of is_live.

create policy "public reads option groups of live restaurants, owner reads own"
  on option_groups for select
  using (
    exists (
      select 1 from menu_items mi
      join restaurants r on r.id = mi.restaurant_id
      where mi.id = option_groups.menu_item_id
        and (r.is_live = true or r.owner_user_id = auth.uid())
    )
  );

create policy "owner can manage own option groups"
  on option_groups for all
  using (
    exists (
      select 1 from menu_items mi
      join restaurants r on r.id = mi.restaurant_id
      where mi.id = option_groups.menu_item_id
        and r.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from menu_items mi
      join restaurants r on r.id = mi.restaurant_id
      where mi.id = option_groups.menu_item_id
        and r.owner_user_id = auth.uid()
    )
  );

create policy "public reads option choices of live restaurants, owner reads own"
  on option_choices for select
  using (
    exists (
      select 1 from option_groups og
      join menu_items mi on mi.id = og.menu_item_id
      join restaurants r on r.id = mi.restaurant_id
      where og.id = option_choices.option_group_id
        and (r.is_live = true or r.owner_user_id = auth.uid())
    )
  );

create policy "owner can manage own option choices"
  on option_choices for all
  using (
    exists (
      select 1 from option_groups og
      join menu_items mi on mi.id = og.menu_item_id
      join restaurants r on r.id = mi.restaurant_id
      where og.id = option_choices.option_group_id
        and r.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from option_groups og
      join menu_items mi on mi.id = og.menu_item_id
      join restaurants r on r.id = mi.restaurant_id
      where og.id = option_choices.option_group_id
        and r.owner_user_id = auth.uid()
    )
  );
