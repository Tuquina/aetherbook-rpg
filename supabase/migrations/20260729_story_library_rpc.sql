-- The home dashboard's "Sigue leyendo" carousel and the new MyStoriesScreen
-- (V2 design prototype §8a/§2b) both need every session the account owns,
-- across all 3 story modules, sorted by recency, with turn count/status/
-- character name in one shot. Neither `reading_stats()` (no recency, no
-- character name — built for Perfil's aggregates) nor `listActiveSessions`
-- (no turn count/status, active-only — built for "tus historias") covers
-- this, so it gets its own purpose-built function rather than overloading
-- either.
create or replace function story_library()
returns table (
  session_id uuid,
  world_slug text,
  status text,
  title text,
  character_name text,
  turn_count bigint,
  updated_at timestamptz
)
language sql
security invoker
stable
set search_path = public
as $$
  select
    gs.id,
    gs.world_slug,
    gs.status,
    gs.title,
    c.name,
    count(t.id),
    gs.updated_at
  from game_sessions gs
  left join turns t on t.session_id = gs.id
  left join characters c on c.session_id = gs.id
  where gs.user_id = auth.uid()
  group by gs.id, gs.world_slug, gs.status, gs.title, c.name, gs.updated_at
  order by gs.updated_at desc;
$$;
