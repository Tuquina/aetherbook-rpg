-- World Builder (Admin Stage 2, project decision 2026-07-31: "permitir un
-- sistema de atributos propio desde cero"): an admin-authored official
-- campaign no longer has to borrow attributes/resources/theme/narrator tone
-- from an existing bundled world via `base_world_slug` — it can declare its
-- own from scratch, stored here as the exact JSON shape `World.toJson()`/
-- `World.fromJson` already round-trip (`core/world/world.dart`), minus the
-- `'graph'` key: this table already has its own `graph` column
-- (`20260730_campaign_drafts.sql`), which stays the one source of truth for
-- the node graph — a custom world's own `storyGraph` is always ignored.
--
-- Exactly one of `base_world_slug`/`custom_world` is ever set. Every existing
-- row already has `base_world_slug` and no `custom_world`, so the check
-- constraint holds immediately with no backfill needed.

alter table campaign_drafts
  alter column base_world_slug drop not null;

alter table campaign_drafts
  add column if not exists custom_world jsonb;

alter table campaign_drafts
  add constraint campaign_drafts_world_source_check
    check (num_nonnulls(base_world_slug, custom_world) = 1);
