-- DoorFeast — Step 2 seed data: Foji's Ice Lounge (Burslem)
-- Source: https://www.fojisicelounge.uk/ (scraped 2026-08-07)
--
-- IMPORTANT — this restaurant is inserted with is_live = false on purpose.
-- Nothing here is visible to the public (RLS only exposes is_live = true
-- restaurants) until ALL of the following are fixed:
--
--   1. ALLERGENS — every item below has allergens set to the placeholder
--      'TODO - confirm with restaurant'. This is a legal requirement
--      (UK Food Information Regulations) and cannot go live with a
--      placeholder. Replace every occurrence with real allergen info
--      from the founder before flipping is_live to true.
--
--   2. PRICES — prices below are the RAW prices from the current site,
--      copied as-is (no fee added). CLAUDE.md requires the £0.50
--      customer service fee to be baked into price_pence before an
--      item ever goes live. Add 50 to every price_pence value (or run
--      an UPDATE statement) before launch.
--
--   3. delivery_fee_pence, min_order_pence, delivery_postcodes are all
--      NULL — not shown anywhere on the source site. Confirm with the
--      founder and fill in before launch.
--
--   4. opening_hours — Wednesday hours were not listed on the source
--      site (could mean closed, or a scrape gap). Confirmed as "closed"
--      here — verify with the founder.
--
-- Run this after supabase/schema.sql.

-- ============================================================
-- Restaurant
-- ============================================================
insert into restaurants (
  name, slug, address, postcode, phone, cuisine,
  is_live, does_delivery, does_collection,
  delivery_fee_pence, min_order_pence, delivery_postcodes,
  opening_hours
) values (
  'Foji''s Ice Lounge',
  'fojis-ice-lounge',
  '15 Market Pl, Burslem',
  'ST6 3AA',
  '01782 278703',
  'Desserts',
  false,
  true,
  true,
  null,
  null,
  null,
  '{
    "mon": "16:00-21:00",
    "tue": "16:00-21:00",
    "wed": "closed",
    "thu": "16:00-21:00",
    "fri": "16:00-21:20",
    "sat": "16:00-21:20",
    "sun": "16:00-21:30"
  }'::jsonb
);

-- ============================================================
-- Categories
-- ============================================================
insert into menu_categories (restaurant_id, name, sort_order)
select r.id, v.name, v.sort_order
from restaurants r, (values
  ('Date Night Offer', 1),
  ('New Viral Cake in Can', 2),
  ('New Dubai Kunafa', 3),
  ('Viral Krunch Cake', 4),
  ('Summer Offers (Collection Only)', 5),
  ('Any Day Offer', 6),
  ('Strawberry Heaven Mash', 7),
  ('Magic Box', 8),
  ('Friday Offer', 9),
  ('New Combo Milkshake Offer', 10),
  ('Pick N Mix', 11),
  ('Cookie Dough', 12),
  ('Waffles', 13),
  ('Bubble Waffles', 14),
  ('Milkshakes', 15),
  ('Luxury Shakes', 16),
  ('Smoothies', 17),
  ('Cakes', 18),
  ('Churros', 19),
  ('Doughnuts', 20),
  ('Ice Cream', 21),
  ('Gelato Milkshakes', 22),
  ('Gelato Scoops', 23),
  ('Crepes', 24),
  ('Sundaes', 25),
  ('Pancakes', 26),
  ('Mojito', 27),
  ('Sweets & Chocolate Bars', 28)
) as v(name, sort_order)
where r.slug = 'fojis-ice-lounge';

-- ============================================================
-- Menu items (one insert per category)
-- allergens placeholder on every row — see note at top of file.
-- ============================================================

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Date Night Offer'
cross join (values
  ('2 Cookie Dough, 2 Milkshakes', null, 1900)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'New Viral Cake in Can'
cross join (values
  ('Cake Can', 'Layers of velvety mousse, rich fudge, and chocolate overloaded', 599)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'New Dubai Kunafa'
cross join (values
  ('Dubai Kunafa Shake', 'Milkshake with kunafa, syrup, whipped cream, and pistachios', 500),
  ('Dubai Kunafa Cup', 'Layered kunafa dessert with pistachios', 500),
  ('Dubai Kunafa Cookie Dough', 'Warm cookie dough with kunafa and vanilla ice cream', 650),
  ('Dubai Kunafa Waffle', 'Crispy waffle with kunafa, syrup, and pistachios', 650)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Viral Krunch Cake'
cross join (values
  ('Mini Eggs Krunch Cake', null, 500),
  ('Kinder Bueno Krunch Cake', null, 500),
  ('Oreo Krunch Cake', null, 500)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Summer Offers (Collection Only)'
cross join (values
  ('Get 2 Milkshakes & 3rd One Free', null, 1000)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Any Day Offer'
cross join (values
  ('Any 2 Classic Milkshakes', null, 800)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Strawberry Heaven Mash'
cross join (values
  ('Strawberry Heaven Mash', null, 650)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Magic Box'
cross join (values
  ('Magic Box 1', 'Bubble waffle, 12 mini doughnuts, strawberry and chocolate milkshake', 1500),
  ('Magic Box 2', 'Waffle ball, smoothie, milkshake', 1175)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Friday Offer'
cross join (values
  ('2 X Waffle', null, 900)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'New Combo Milkshake Offer'
cross join (values
  ('Combo Milkshake', null, 499)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Pick N Mix'
cross join (values
  ('Small', null, 100),
  ('Medium', null, 200),
  ('Large', null, 400)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Cookie Dough'
cross join (values
  ('Original Chocolate Cookie Dough', 'Served with vanilla ice cream tub', 550),
  ('Nutty Nutella Cookie Dough', 'Served with vanilla ice cream tub', 550),
  ('Strawberry Sensation Cookie Dough', 'Served with vanilla ice cream tub', 700),
  ('Smarties Cookie Dough', 'Served with vanilla ice cream tub', 700),
  ('Aero Chocolate Cookie Dough', 'Served with vanilla ice cream tub', 600),
  ('Terrys Choc Orange Cookie Dough', 'Served with vanilla ice cream tub', 700),
  ('Kinder Bueno Cookie Dough', 'Served with vanilla ice cream tub', 750),
  ('Ferrero Rocher Cookie Dough', 'Served with vanilla ice cream tub', 750)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Waffles'
cross join (values
  ('Nutella Waffle', 'Served with vanilla ice cream tub', 600),
  ('Strawberry Waffle', 'Served with vanilla ice cream tub', 600),
  ('Terrys Choc Orange Waffle', 'Served with vanilla ice cream tub', 700),
  ('Kinder Bueno Waffle', 'Served with vanilla ice cream tub', 800),
  ('Lotus Biscoff Waffle', 'Biscoff crumbles topped with warm, silky sauce. Served with vanilla ice cream tub', 800),
  ('Ferrero Rocher Waffle', 'Served with vanilla ice cream tub', 800),
  ('Strawberry Banana Waffle', 'Served with vanilla ice cream tub', 600)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Bubble Waffles'
cross join (values
  ('Oreo Bubble Waffle', null, 600),
  ('Kinder Bueno Bubble Waffle', null, 600),
  ('Lotus Biscoff Bubble Waffle', null, 600),
  ('Ferrero Rocher Bubble Waffle', null, 630)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Milkshakes'
cross join (values
  ('Bubbly Banana', null, 400),
  ('Sweet Strawberry', null, 400),
  ('Creamy Chocolate', null, 400),
  ('Ferrero Rocher', null, 450),
  ('Flake', null, 450),
  ('Aero Mint', null, 450),
  ('Create Your Own', null, 450),
  ('Oreo Cookie', null, 450),
  ('Smarties', null, 450),
  ('Skittles', null, 450),
  ('Terrys Choc Orange', null, 450),
  ('Jammie Dodgers', null, 450),
  ('Aero', null, 450),
  ('Galaxy', null, 450),
  ('Bounty', null, 450),
  ('Twirl', null, 450),
  ('Malteasers', null, 450),
  ('Bubblegum', null, 450),
  ('Kinder Bueno', null, 450),
  ('Lotus Biscoff', null, 450),
  ('Reese''s', null, 450),
  ('Crunchie', null, 450),
  ('Dairy Milk Caramel', null, 450),
  ('Royal Shake', null, 500),
  ('Strawberry Madness Shake', 'Fresh strawberries, jammie dodgers, whipped cream', 500),
  ('Bubblicious Shake', 'Skittles, millions, whipped cream', 500),
  ('Strawreo Shake', 'Oreos, strawberries, whipped cream', 500),
  ('Smartie Kat Shake', 'Smarties, kitkat, whipped cream', 500)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Luxury Shakes'
cross join (values
  ('The Prince Charming Shake', null, 500),
  ('The Princess Shake', null, 500),
  ('Dreamy Shake', null, 500),
  ('Strawberry Madness Shake', null, 550),
  ('Rainbow Shake', null, 550),
  ('Strawberry & Oreo Shake', null, 550),
  ('Kitkat & Smarties Shake', null, 550),
  ('Big Bang Shake', null, 550)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Smoothies'
cross join (values
  ('Mango Blast', null, 350),
  ('Berrylicious', null, 350),
  ('Blueberry', null, 350),
  ('Strawberry', null, 350),
  ('Create Your Own', null, 400)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Cakes'
cross join (values
  ('Apple Crumble', null, 550),
  ('San Sebastian Cheesecake', null, 550),
  ('Jam Roll Poly', null, 550),
  ('Chocolate Brownie', null, 550),
  ('Strawberry Cheesecake', null, 550),
  ('Sprinkle Cake Slice', null, 550),
  ('Viral Dream Cake', null, 700)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Churros'
cross join (values
  ('Churros', 'Golden, crispy-on-the-outside and fluffy-on-the-inside dough sticks', 450)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Doughnuts'
cross join (values
  ('3 Doughnuts', null, 500),
  ('7 Doughnuts', null, 800),
  ('8pcs Mini Doughnuts', null, 200),
  ('12pcs Mini Doughnuts', null, 300)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Ice Cream'
cross join (values
  ('Create Your Own Ice Cream', null, 450)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Gelato Milkshakes'
cross join (values
  ('Cookies N Cream', null, 500),
  ('Deluxe Chocolate', null, 500),
  ('Lotus Biscoff', null, 500),
  ('Vanilla', null, 500),
  ('Strawberry', null, 500)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Gelato Scoops'
cross join (values
  ('2 Gelato Scoops', null, 350)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Crepes'
cross join (values
  ('Strawella Crepe', 'Strawberry with Nutella', 550),
  ('Lotus Biscoff Crepe', null, 550),
  ('Millionaires Crepe', null, 650),
  ('Kiddie Fantasy Crepe', 'Kinder Bueno and chocolate sauce', 550),
  ('Cookie Creations Crepe', 'Oreos and chocolate spread', 550),
  ('Create Your Own Crepe', null, 550)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Sundaes'
cross join (values
  ('The Oreo Sundae', null, 600),
  ('Ferrero Rocher Sundae', null, 600),
  ('Strawberry Sundae', null, 600)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Pancakes'
cross join (values
  ('Mini Pancakes', 'Fluffy bite-sized pancakes, stacked and served warm', 500)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Mojito'
cross join (values
  ('Lemon And Lime', null, 400),
  ('Strawberry', null, 400),
  ('Blue Ocean', null, 400)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

insert into menu_items (restaurant_id, category_id, name, description, price_pence, allergens, is_available)
select r.id, c.id, v.name, v.description, v.price_pence, array['TODO - confirm with restaurant'], true
from restaurants r
join menu_categories c on c.restaurant_id = r.id and c.name = 'Sweets & Chocolate Bars'
cross join (values
  ('Flake', null, 100),
  ('Kinder Bueno Bar', null, 100),
  ('Bounty Bar', null, 100)
) as v(name, description, price_pence)
where r.slug = 'fojis-ice-lounge';

-- Note: "Asian Food" category from the source site was skipped — it was
-- listed as "pre-order only" with no items shown.
