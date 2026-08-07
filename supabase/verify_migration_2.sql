-- Confirms migration 2 landed: new tables exist with RLS on, new columns
-- exist on restaurants, and the storage buckets were created.

select 'tables' as check_type, c.relname as name, c.relrowsecurity::text as rls_enabled_or_public, count(p.policyname)::text as policy_count
from pg_class c
left join pg_policies p on p.tablename = c.relname
where c.relname in ('restaurant_applications','admins','waitlist_signups')
  and c.relkind = 'r'
group by c.relname, c.relrowsecurity

union all

select 'restaurants columns', column_name, null::text, null::text
from information_schema.columns
where table_name = 'restaurants' and column_name in ('owner_user_id','lat','lng')

union all

select 'storage buckets', id, public::text, null::text
from storage.buckets
where id in ('application-documents','menu-photos')

order by check_type, name;
