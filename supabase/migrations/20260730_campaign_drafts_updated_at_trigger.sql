-- Auto-bumps `updated_at` on every UPDATE. None of the pre-existing tables
-- do this (their `updated_at` is effectively just "created_at" today — a
-- pre-existing gap this migration doesn't touch), but the editor's map
-- screen (V2 design prototype §9a: "Guardado hace 1 min") genuinely needs a
-- correct autosave timestamp on this new table, so it gets a real trigger
-- instead of relying on the client to remember to set it on every write.

create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger campaign_drafts_set_updated_at
  before update on campaign_drafts
  for each row
  execute function set_updated_at();
