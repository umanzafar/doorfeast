-- DoorFeast — Migration 7: first-order discount fraud prevention
-- Run after migration_6.
--
-- Two automatic checks, both run as database triggers (SECURITY DEFINER,
-- same pattern as the new-restaurant notification trigger) since they
-- need to compare against OTHER customers' data, which normal RLS
-- correctly forbids a customer from reading directly:
--
--   1. Duplicate PHONE — once a customer verifies a phone number (via
--      Supabase's built-in phone-OTP flow), if that same verified phone
--      is already on a different account, this account loses discount
--      eligibility.
--   2. Duplicate ADDRESS — when a customer saves an address, if the same
--      address (line1 + postcode, normalized) already belongs to a
--      different customer, this account loses discount eligibility.
--
-- Card-fingerprint checking (the strongest signal) is deferred until
-- Stripe Connect/checkout exists — there's nowhere to check a card yet.

alter table customers add column phone_verified boolean not null default false;
alter table customers add column discount_eligible boolean not null default true;

-- ============================================================
-- Duplicate phone check
-- ============================================================
create or replace function check_duplicate_phone()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.phone_verified = true and (OLD.phone_verified is distinct from true) then
    if exists (
      select 1 from customers
      where phone = NEW.phone
        and phone_verified = true
        and id != NEW.id
    ) then
      NEW.discount_eligible := false;
    end if;
  end if;
  return NEW;
end;
$$;

create trigger trg_check_duplicate_phone
before update on customers
for each row
execute function check_duplicate_phone();

-- ============================================================
-- Duplicate address check
-- ============================================================
create or replace function check_duplicate_address()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_new text;
  dup_count int;
begin
  normalized_new := lower(trim(NEW.line1)) || '|' || lower(trim(NEW.postcode));

  select count(*) into dup_count
  from customer_addresses a
  where a.customer_id != NEW.customer_id
    and lower(trim(a.line1)) || '|' || lower(trim(a.postcode)) = normalized_new;

  if dup_count > 0 then
    update customers set discount_eligible = false where id = NEW.customer_id;
  end if;

  return NEW;
end;
$$;

create trigger trg_check_duplicate_address
after insert on customer_addresses
for each row
execute function check_duplicate_address();
