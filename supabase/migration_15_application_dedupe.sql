-- DoorFeast — Migration 15: application dedupe
-- Run after migration_14.
--
-- application.html had no guard against a user submitting the application
-- form twice (e.g. two tabs, or a resubmit after a network hiccup). The
-- client now checks for an existing application before rendering the
-- wizard, but that's a race-prone check on its own — this is the actual
-- backstop. A partial unique index (rather than a plain unique constraint
-- on user_id) so a rejected applicant can still submit a fresh application
-- later; it only blocks having two 'pending' rows at once.

create unique index restaurant_applications_one_pending_per_user
  on restaurant_applications (user_id)
  where status = 'pending';
