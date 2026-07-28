-- A generated character portrait (V2 §4c) — fixed for the whole story,
-- generated once right after chargen, unlike `turns.image_url` (one image
-- per turn). Nullable: never generated, or generation failed
-- (`ImageGeneratorPort` never throws — a missing avatar just means no
-- portrait, same "nice to have" degradation as scene images).
alter table characters add column if not exists avatar_url text;
