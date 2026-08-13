-- DoorFeast — Migration 6: customer notifications (bell icon)
-- Run after migration_5.
--
-- Two things write notifications:
--   1. The customer themselves, right after they update their profile or
--      photo (a simple client-side insert, covered by the insert policy).
--   2. A database trigger, whenever a restaurant flips is_live to true —
--      fires automatically, notifies every existing customer. Runs as
--      SECURITY DEFINER since it inserts rows for customers other than
--      whoever's making the restaurants change (an admin/RLS bypass is
--      correct here, not a workaround).

create table customer_notifications (
  id           uuid primary key default gen_random_uuid(),
  customer_id  uuid not null references customers(id) on delete cascade,
  title        text not null,
  message      text,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);

alter table customer_notifications enable row level security;

create policy "customer can read own notifications"
  on customer_notifications for select
  using (exists (select 1 from customers c where c.id = customer_notifications.customer_id and c.user_id = auth.uid()));

create policy "customer can insert own notifications"
  on customer_notifications for insert
  with check (exists (select 1 from customers c where c.id = customer_notifications.customer_id and c.user_id = auth.uid()));

create policy "customer can mark own notifications read"
  on customer_notifications for update
  using (exists (select 1 from customers c where c.id = customer_notifications.customer_id and c.user_id = auth.uid()))
  with check (exists (select 1 from customers c where c.id = customer_notifications.customer_id and c.user_id = auth.uid()));

-- ============================================================
-- Trigger: notify every customer when a restaurant goes live
-- ============================================================
create or replace function notify_customers_new_restaurant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (NEW.is_live = true and OLD.is_live is distinct from true) then
    insert into customer_notifications (customer_id, title, message)
    select id, 'New restaurant on DoorFeast', NEW.name || ' just joined DoorFeast — check out their menu.'
    from customers;
  end if;
  return NEW;
end;
$$;

create trigger trg_notify_new_restaurant
after update on restaurants
for each row
execute function notify_customers_new_restaurant();
