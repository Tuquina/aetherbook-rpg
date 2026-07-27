-- Player-chosen narrative tone at chargen (V2 design prototype's tone step:
-- épico/íntimo/ácido). Nullable — worlds that declare no `tones` (every
-- world/character predating this field) never set it, and it never gates
-- mechanics: it's read only as a narrator-prompt instruction.
alter table characters add column if not exists chosen_tone text;
