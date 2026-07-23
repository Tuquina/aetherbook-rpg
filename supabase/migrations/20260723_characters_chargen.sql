-- Structured character creation (campaign-bible §5): origin, its denormalized
-- tag, vow, and the personal item's free-text description. All nullable —
-- worlds without structured chargen (Fase 0 style) never set them.
alter table characters add column if not exists origin_id text;
alter table characters add column if not exists origin_tag_id text;
alter table characters add column if not exists vow_id text;
alter table characters add column if not exists personal_item text;
