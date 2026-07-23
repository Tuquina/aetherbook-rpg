-- Lets a resumed session show the same choices it last offered, instead of
-- re-invoking the narrator (and spending quota) just to redisplay options.
alter table turns add column if not exists suggested_choices jsonb not null default '[]'::jsonb;
