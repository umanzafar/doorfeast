-- DoorFeast — Migration 11: let a restaurant owner read their own orders
-- Run after migration_10. Previously only customers could read orders
-- (their own, from migration_3) — restaurant owners had no read access
-- at all, so the dashboard's "Paid orders" stat would silently always
-- show 0 due to RLS, not because there are genuinely no orders. This is
-- read-only; write access (accept/reject/status changes) is a separate
-- decision for when the order inbox itself gets built.

create policy "owner can read own restaurant orders"
  on orders for select
  using (
    exists (
      select 1 from restaurants r
      where r.id = orders.restaurant_id
        and r.owner_user_id = auth.uid()
    )
  );
