-- Fase 1 game state schema (GDD §8, event-sourced light: `turns` is the log,
-- current state is its projection). Content (worlds/campaigns) stays as
-- bundled declarative JSON on the client (CLAUDE.md §8) — only player state
-- lives here. RLS: each user sees only their own sessions and everything
-- that hangs off them.

create table if not exists game_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  world_slug text not null,
  campaign_slug text,
  status text not null default 'active'
    check (status in ('active', 'completed', 'abandoned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists game_sessions_user_id_idx on game_sessions(user_id);

create table if not exists characters (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null unique references game_sessions(id) on delete cascade,
  name text not null,
  level int not null default 1,
  exp int not null default 0,
  attributes jsonb not null default '{}'::jsonb,
  resources jsonb not null default '{}'::jsonb,
  flags jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists inventory_items (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references game_sessions(id) on delete cascade,
  key text not null,
  name text not null,
  props jsonb not null default '{}'::jsonb,
  qty int not null default 1,
  created_at timestamptz not null default now(),
  unique (session_id, key)
);

create table if not exists relationships (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references game_sessions(id) on delete cascade,
  npc_key text not null,
  disposition text not null default 'neutral',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (session_id, npc_key)
);

create table if not exists turns (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references game_sessions(id) on delete cascade,
  turn_index int not null,
  player_action text not null,
  resolved_mechanics jsonb,
  narration text not null,
  image_url text,
  created_at timestamptz not null default now(),
  unique (session_id, turn_index)
);

create table if not exists memory_digests (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references game_sessions(id) on delete cascade,
  up_to_turn int not null,
  summary_text text not null,
  created_at timestamptz not null default now(),
  unique (session_id, up_to_turn)
);

-- RLS: a user only ever sees rows that hang off their own game_sessions.
alter table game_sessions enable row level security;
alter table characters enable row level security;
alter table inventory_items enable row level security;
alter table relationships enable row level security;
alter table turns enable row level security;
alter table memory_digests enable row level security;

create policy "own sessions" on game_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own characters" on characters
  for all using (
    exists (
      select 1 from game_sessions gs
      where gs.id = characters.session_id and gs.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from game_sessions gs
      where gs.id = characters.session_id and gs.user_id = auth.uid()
    )
  );

create policy "own inventory_items" on inventory_items
  for all using (
    exists (
      select 1 from game_sessions gs
      where gs.id = inventory_items.session_id and gs.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from game_sessions gs
      where gs.id = inventory_items.session_id and gs.user_id = auth.uid()
    )
  );

create policy "own relationships" on relationships
  for all using (
    exists (
      select 1 from game_sessions gs
      where gs.id = relationships.session_id and gs.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from game_sessions gs
      where gs.id = relationships.session_id and gs.user_id = auth.uid()
    )
  );

create policy "own turns" on turns
  for all using (
    exists (
      select 1 from game_sessions gs
      where gs.id = turns.session_id and gs.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from game_sessions gs
      where gs.id = turns.session_id and gs.user_id = auth.uid()
    )
  );

create policy "own memory_digests" on memory_digests
  for all using (
    exists (
      select 1 from game_sessions gs
      where gs.id = memory_digests.session_id and gs.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from game_sessions gs
      where gs.id = memory_digests.session_id and gs.user_id = auth.uid()
    )
  );
