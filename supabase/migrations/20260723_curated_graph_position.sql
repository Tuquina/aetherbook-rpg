-- Persist a curated/hybrid session's position in the world's StoryGraph, and
-- the character state that was never wired to Postgres despite existing in
-- the Dart domain (lib/core/state/character.dart): relationships, and the
-- new generic `lists`/`vars` maps (lib/core/state/character.dart). Without
-- this, closing the app mid-campaign restarted at StoryGraph.startNodeId
-- (CLAUDE.md §11) and silently dropped every relationship change.
alter table game_sessions add column if not exists current_node_id text;
alter table game_sessions add column if not exists corridor_turns_used int not null default 0;
alter table game_sessions add column if not exists extended_conflict_progress jsonb;

alter table characters add column if not exists relationships jsonb not null default '{}'::jsonb;
alter table characters add column if not exists lists jsonb not null default '{}'::jsonb;
alter table characters add column if not exists vars jsonb not null default '{}'::jsonb;
