-- Quick check: confirms all 5 tables exist and RLS is enabled on each.
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  count(p.policyname) as policy_count
from pg_class c
left join pg_policies p on p.tablename = c.relname
where c.relname in ('restaurants','menu_categories','menu_items','orders','order_items')
  and c.relkind = 'r'
group by c.relname, c.relrowsecurity
order by c.relname;
