-- The home dashboard's "Dejaste el tomo abierto" hero (V2 §8a/§8b) quotes
-- the most recent turn's narration and uses its scene image as a
-- background — story_library() didn't select either. Replaces the
-- `left join turns + group by` aggregation with a `left join lateral` to
-- the single most recent turn per session (ordered by turn_index desc,
-- limit 1) — simpler than growing the group-by list a third time, and
-- turn_count becomes a plain scalar subquery instead of count(t.id).
--
-- The return shape changed again (2 new OUT columns), so `create or
-- replace` isn't enough — same 42P13 the two prior migrations on this
-- function hit; drop first.
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
  current_node_id text,
  last_narration text,
  last_image_url text
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
    (select count(*) from turns t2 where t2.session_id = gs.id),
    gs.updated_at,
    gs.current_node_id,
    lt.narration,
    lt.image_url
  from game_sessions gs
  left join characters c on c.session_id = gs.id
  left join lateral (
    select t.narration, t.image_url
    from turns t
    where t.session_id = gs.id
    order by t.turn_index desc
    limit 1
  ) lt on true
  where gs.user_id = auth.uid()
  order by gs.updated_at desc;
$$;
