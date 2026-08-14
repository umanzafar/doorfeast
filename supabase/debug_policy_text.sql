select policyname, cmd, qual, with_check
from pg_policies
where tablename = 'objects'
  and policyname in ('owner can upload own restaurant logo', 'owner can upload own menu photos');
