-- DoorFeast — Migration 8: order tracking page support
-- Run after migration_7.
--
-- order_items had RLS enabled from the start but zero policies (only
-- service_role could read it) — correct while no customer-facing order
-- page existed, but order.html needs a customer to read the items on
-- their own order. Also enables Realtime on orders so the tracking page
-- updates live when the restaurant changes the order's status, instead
-- of needing a manual refresh.

create policy "customer can read own order items"
  on order_items for select
  using (
    exists (
      select 1 from orders o
      join customers c on c.id = o.customer_id
      where o.id = order_items.order_id
        and c.user_id = auth.uid()
    )
  );

alter publication supabase_realtime add table orders;
