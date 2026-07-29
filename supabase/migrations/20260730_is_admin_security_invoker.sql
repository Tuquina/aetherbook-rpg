-- is_admin() only ever reads the calling role's own JWT claims (auth.jwt())
-- — it never needs to run with the definer's elevated privileges, so
-- `security definer` was unnecessary and the linter flags any definer
-- function as directly RPC-callable by anon/authenticated (0028/0029).
-- Recreated as the default `security invoker` instead, functionally
-- identical for RLS purposes. `create or replace`, not drop+create: two RLS
-- policies already depend on this function's signature.
create or replace function is_admin() returns boolean
language sql stable security invoker set search_path = public as $$
  select coalesce(auth.jwt() ->> 'email', '') in (
    'carrizoaagustin@gmail.com',
    'fernandotuquina@gmail.com',
    'franjaime2016@gmail.com',
    'francoq96@gmail.com',
    'aetherbook.app@gmail.com'
  );
$$;
