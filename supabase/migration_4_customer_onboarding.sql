-- DoorFeast — Migration 4: customer onboarding
-- Run after migration_3. Adds fields the onboarding wizard (customer/onboarding.html)
-- writes to on a new customer's first visit. No new RLS needed — the
-- existing "customer can update own row" policy on customers, and
-- "customer can manage own addresses" policy on customer_addresses,
-- already cover these writes.

alter table customers add column cuisine_interests text[];
alter table customers add column heard_from text;
alter table customers add column onboarding_completed boolean not null default false;
