-- Checks whether the restaurant the logo upload was attempted for
-- actually has owner_user_id pointing at your logged-in account.
select
  r.id as restaurant_id,
  r.name as restaurant_name,
  r.owner_user_id,
  u.email as owner_email
from restaurants r
left join auth.users u on u.id = r.owner_user_id
where r.id = '65f24cf1-d578-426a-ad20-93d9ef0db131';
