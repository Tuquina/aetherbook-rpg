-- Admin-authored official campaigns (project decision 2026-07-30): unlike a
-- community novel published via the editor (which only ever shows up in
-- "Explorar"), an admin can mark a campaign_drafts row as an official
-- "historia completa" or "historia híbrida" — one of the two catalog
-- modules `WorldSelectScreen.moduleFor` already classifies by `World.
-- aiRuntimeRequired` (`false` -> completa, `true` -> híbrida). This is the
-- first role-based (not single-owner) RLS in this schema — every other
-- table/policy so far is strictly `auth.uid() = user_id`.
--
-- The admin list is a small, hand-picked set for now (not a `role` column
-- on `auth.users` — no user-management surface exists to assign one yet).
-- Kept as a single SQL function so every admin-aware policy references one
-- place instead of repeating the email list.
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(auth.jwt() ->> 'email', '') in (
    'carrizoaagustin@gmail.com',
    'fernandotuquina@gmail.com',
    'franjaime2016@gmail.com',
    'francoq96@gmail.com',
    'aetherbook.app@gmail.com'
  );
$$;

alter table campaign_drafts
  add column if not exists official_module text
    check (official_module in ('complete', 'hybrid'));

-- Replaces the original "own campaign drafts" policy from
-- 20260730_campaign_drafts.sql: same shape, plus the write-side check that
-- only an admin may ever set `official_module` on a row — a non-admin's own
-- drafts must keep `official_module` null. Read-side (`using`) is
-- unchanged: an author still sees every status of their own row.
drop policy if exists "own campaign drafts" on campaign_drafts;

create policy "own campaign drafts" on campaign_drafts
  for all using (auth.uid() = author_id)
  with check (auth.uid() = author_id and (official_module is null or is_admin()));

-- Any admin can read/write ANY row once it's flagged official, regardless
-- of who authored it — "revisar y editar todas las historias completas e
-- híbridas", not just the ones a given admin happened to create.
create policy "admins manage official campaigns" on campaign_drafts
  for all using (official_module is not null and is_admin())
  with check (official_module is not null and is_admin());
