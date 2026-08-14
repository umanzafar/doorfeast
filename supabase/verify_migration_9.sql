-- Confirms migration_9 actually landed: the column, the bucket, and all
-- 4 storage policies for restaurant-logos.
select 'column' as check_type, column_name as name, null as extra
from information_schema.columns
where table_name = 'restaurants' and column_name = 'logo_url'

union all

select 'bucket', id, public::text
from storage.buckets
where id = 'restaurant-logos'

union all

select 'policy', policyname, cmd::text
from pg_policies
where tablename = 'objects' and policyname ilike '%restaurant logo%'

order by check_type;
