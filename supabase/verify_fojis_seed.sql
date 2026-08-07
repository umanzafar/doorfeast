-- Confirms Foji's Ice Lounge seed landed correctly.
select
  r.name,
  r.is_live,
  (select count(*) from menu_categories c where c.restaurant_id = r.id) as category_count,
  (select count(*) from menu_items i where i.restaurant_id = r.id) as item_count,
  (select count(*) from menu_items i where i.restaurant_id = r.id and 'TODO - confirm with restaurant' = any(i.allergens)) as items_with_todo_allergens
from restaurants r
where r.slug = 'fojis-ice-lounge';
