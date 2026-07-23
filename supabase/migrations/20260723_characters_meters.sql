-- Named narrative-economy counters (karma, celestial_pressure, ledger_debt,
-- public_trust, etc.) that a campaign bible declares beyond attributes and
-- resources. See lib/core/world/meter_definition.dart.
alter table characters add column if not exists meters jsonb not null default '{}'::jsonb;
