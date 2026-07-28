-- Account-wide player preferences (V2 design prototype §6b: Ajustes) and the
-- "has this account seen the first-run onboarding" flag (§6c-e) — both are
-- per-account, not per-session, so they get their own 1-row-per-user table
-- rather than hanging off game_sessions (CLAUDE.md §7's convention of one
-- jsonb bucket for everything that would've been its own column, same as
-- characters.flags/vars/meters).
create table if not exists user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table user_settings enable row level security;

create policy "own settings" on user_settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
