-- Perfil (V2 design prototype §6a) needs aggregate reading stats across all
-- of a user's sessions: tomos/turnos/terminadas, a per-world turn breakdown,
-- and each session's vow outcome. PostgREST has no GROUP BY, and fetching
-- every turn row client-side just to count them doesn't scale — one
-- `security invoker` function (runs as the caller, so RLS on game_sessions/
-- turns/characters still applies) returns one row per session; the client
-- aggregates tomos/turnos/per-world/juramentos from that single result set.
create or replace function reading_stats()
returns table (
  session_id uuid,
  world_slug text,
  status text,
  title text,
  turn_count bigint,
  vow_id text,
  vow_status text,
  vow_tested_count int
)
language sql
security invoker
stable
as $$
  select
    gs.id,
    gs.world_slug,
    gs.status,
    gs.title,
    count(t.id),
    c.vow_id,
    c.vars ->> 'vow_status',
    coalesce((c.meters ->> 'vow_tested_count')::int, 0)
  from game_sessions gs
  left join turns t on t.session_id = gs.id
  left join characters c on c.session_id = gs.id
  where gs.user_id = auth.uid()
  group by gs.id, gs.world_slug, gs.status, gs.title, c.vow_id, c.vars, c.meters;
$$;
