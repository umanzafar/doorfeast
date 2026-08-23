-- Simulates a real paid order for testing the order inbox — no Stripe
-- needed. Replace YOUR_RESTAURANT_OWNER_EMAIL with the email you log
-- into dashboard.html with, then run this. It should appear in your
-- Order Inbox within a couple of seconds (Realtime), with the alert
-- sound playing, if the dashboard tab is open.

do $$
declare
  v_restaurant_id uuid;
  v_order_id uuid;
  v_item record;
  v_subtotal integer := 0;
begin
  select r.id into v_restaurant_id
  from restaurants r
  join auth.users u on u.id = r.owner_user_id
  where u.email = 'YOUR_RESTAURANT_OWNER_EMAIL';

  if v_restaurant_id is null then
    raise exception 'No restaurant found for that owner email — check the email is right.';
  end if;

  insert into orders (
    order_number, restaurant_id, customer_name, customer_phone, customer_email,
    order_type, delivery_address, subtotal_pence, delivery_fee_pence, total_pence,
    commission_pence, status, payment_status
  ) values (
    'DF-TEST-' || floor(random() * 9000 + 1000)::text,
    v_restaurant_id, 'Test Customer', '+44 7700 900123', 'test@example.com',
    'collection', null, 0, 0, 0, 0, 'paid', 'paid'
  ) returning id into v_order_id;

  for v_item in
    select id, name, price_pence from menu_items
    where restaurant_id = v_restaurant_id and is_available = true
    limit 2
  loop
    insert into order_items (order_id, menu_item_id, item_name, item_price_pence, quantity, line_total_pence)
    values (v_order_id, v_item.id, v_item.name, v_item.price_pence, 1, v_item.price_pence);
    v_subtotal := v_subtotal + v_item.price_pence;
  end loop;

  update orders
  set subtotal_pence = v_subtotal, total_pence = v_subtotal, commission_pence = round(v_subtotal * 0.12)
  where id = v_order_id;
end $$;
