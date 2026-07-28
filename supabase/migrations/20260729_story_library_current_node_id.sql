-- MyStoriesScreen's real per-chapter progress bar (V2 §2b/§4d, Stage V) needs
-- to know where a curated, AI-free session actually is in its story graph —
-- `story_library()` didn't select it. Chapter number itself is derived
-- client-side from the node id's own `c<N>_...` convention, so no other
-- column is needed. The return shape changed (new OUT column), so `create or
-- replace` isn't enough here — Postgres requires dropping the old signature
-- first (confirmed against the live project: 42P13).
drop function if exists story_library();

create function story_library()
returns table (
  session_id uuid,
  world_slug text,
  status text,
  title text,
  character_name text,
  turn_count bigint,
  updated_at timestamptz,
  current_node_id text
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
    gs.updated_at,
    gs.current_node_id
  from game_sessions gs
  left join turns t on t.session_id = gs.id
  left join characters c on c.session_id = gs.id
  where gs.user_id = auth.uid()
  group by gs.id, gs.world_slug, gs.status, gs.title, c.name, gs.updated_at, gs.current_node_id
  order by gs.updated_at desc;
$$;
