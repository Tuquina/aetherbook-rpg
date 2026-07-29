-- Node display titles (V2 design prototype §9a: every node card shows a
-- short author-facing title — "El maestro del portón" — distinct from its
-- narration/goal body text). Kept as a separate id->title map here rather
-- than a new field on `StoryNode` itself: the engine's node model doesn't
-- need a title to run a turn, only the editor's map/list views do, so it
-- stays out of the `graph` column's `StoryGraph.toJson()` shape entirely
-- (CLAUDE.md §2.5: core/ narrative model has no reason to carry authoring-UI
-- concerns the game engine never reads).

alter table campaign_drafts
  add column if not exists node_titles jsonb not null default '{}'::jsonb;
