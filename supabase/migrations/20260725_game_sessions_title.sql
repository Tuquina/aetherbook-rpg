-- Optional player-chosen title for a session (CLAUDE.md Fase 2: "crea tu
-- propia historia" lets a player start several stories for the same genre at
-- once, so "Tus historias" needs something more identifying than the genre
-- name repeated on every card). Null for every session created before this
-- column existed, and for every non-freeform module, which never asks for one.
alter table game_sessions add column if not exists title text;
