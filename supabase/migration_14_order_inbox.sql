-- DoorFeast — Migration 14: order inbox support
-- Run after migration_13.
--
-- Adds what the restaurant order inbox needs:
--   1. rejection_reason / completed_at columns (documented in CLAUDE.md's
--      schema, never actually added).
--   2. An UPDATE policy letting an owner change their own restaurant's
--      orders (only SELECT existed before, from migration_11).
--   3. A defense-in-depth trigger that silently reverts any attempt to
--      change money/payment/ownership fields via a normal authenticated
--      request — the RLS policy above only checks *which row*, not
--      *which columns*, so this is what actually stops a compromised or
--      malicious owner session from, say, inflating total_pence after
--      the fact. Only service_role (the future create-order/webhook
--      Edge Functions) can touch those fields.
--   4. order_status_history — CLAUDE.md's order lifecycle rules require
--      "every status change writes a row to order_status_history."
--      Implemented as a trigger so it's guaranteed regardless of which
--      client makes the change, not something the dashboard has to
--      remember to do.

alter table orders add column rejection_reason text;
alter table orders add column completed_at timestamptz;

create policy "owner can update own restaurant order"
  on orders for update
  using (
    exists (select 1 from restaurants r where r.id = orders.restaurant_id and r.owner_user_id = auth.uid())
  )
  with check (
    exists (select 1 from restaurants r where r.id = orders.restaurant_id and r.owner_user_id = auth.uid())
  );

create or replace function protect_order_financial_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'authenticated' then
    NEW.subtotal_pence := OLD.subtotal_pence;
    NEW.delivery_fee_pence := OLD.delivery_fee_pence;
    NEW.total_pence := OLD.total_pence;
    NEW.commission_pence := OLD.commission_pence;
    NEW.payment_status := OLD.payment_status;
    NEW.stripe_payment_intent_id := OLD.stripe_payment_intent_id;
    NEW.customer_id := OLD.customer_id;
    NEW.restaurant_id := OLD.restaurant_id;
    NEW.order_number := OLD.order_number;
  end if;
  return NEW;
end;
$$;

create trigger trg_protect_order_financial_fields
before update on orders
for each row
execute function protect_order_financial_fields();

create table order_status_history (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders(id) on delete cascade,
  from_status text,
  to_status   text not null,
  changed_at  timestamptz not null default now()
);

alter table order_status_history enable row level security;

create policy "owner can read own restaurant order history"
  on order_status_history for select
  using (
    exists (
      select 1 from orders o
      join restaurants r on r.id = o.restaurant_id
      where o.id = order_status_history.order_id
        and r.owner_user_id = auth.uid()
    )
  );

create policy "customer can read own order history"
  on order_status_history for select
  using (
    exists (
      select 1 from orders o
      join customers c on c.id = o.customer_id
      where o.id = order_status_history.order_id
        and c.user_id = auth.uid()
    )
  );

create or replace function log_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.status is distinct from OLD.status then
    insert into order_status_history (order_id, from_status, to_status)
    values (NEW.id, OLD.status, NEW.status);
  end if;
  return NEW;
end;
$$;

create trigger trg_log_order_status_change
after update on orders
for each row
execute function log_order_status_change();
