-- Campaign editor (V2 design prototype §9a-9j): lets a player author their own
-- hybrid campaign — a `StoryGraph` of `StoryNode`s (CLAUDE.md §7, §11) — from
-- inside the app, instead of the developer-mediated `assets/worlds/*.json`
-- pipeline every other campaign uses today. `graph` stores exactly the JSON
-- shape `StoryGraph.fromJson`/`StoryNode.fromJson` already parse (`core/
-- narrative/`), so nothing about the graph domain model changes — only a new
-- place for a player-authored one to live before/after publishing.
--
-- A draft is always authored "on top of" an existing world (`base_world_slug`,
-- e.g. 'xianxia') for its attributes, resources, colors and narrator tone
-- (V2 prototype §9f: "Define los atributos, los colores y el tono del
-- narrador") — this table never defines a new attribute system of its own.
--
-- RLS is the one new shape this schema needs (every other table is strictly
-- single-owner, `auth.uid() = user_id`): the author has full access to their
-- own row at any status, and *any* authenticated or anonymous reader can
-- select a row once its status is 'published' — the minimum needed for a
-- published campaign to be playable by someone other than its author.

create table if not exists campaign_drafts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  slug text not null unique,
  title text not null default '',
  synopsis text not null default '',
  base_world_slug text not null,
  status text not null default 'draft'
    check (status in ('draft', 'published')),
  content_warnings text[] not null default '{}',
  cover_image_url text,
  estimated_duration_minutes int,
  ai_runtime_required boolean not null default true,
  -- {"start_node": "...", "nodes": {"node_id": {"type": "fixed_anchor", ...}}}
  -- — the exact shape `StoryGraph.fromJson` parses.
  graph jsonb not null default '{"start_node": "", "nodes": {}}'::jsonb,
  license_accepted_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists campaign_drafts_author_id_idx on campaign_drafts(author_id);
create index if not exists campaign_drafts_status_idx on campaign_drafts(status);

alter table campaign_drafts enable row level security;

create policy "own campaign drafts" on campaign_drafts
  for all using (auth.uid() = author_id) with check (auth.uid() = author_id);

create policy "public read published campaigns" on campaign_drafts
  for select using (status = 'published');
