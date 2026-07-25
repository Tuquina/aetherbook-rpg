-- Public bucket for AI-generated scene images (GDD §6/§7.4). Cached by a
-- deterministic hash of the prompt (see supabase/functions/generate-image),
-- so the same scene never regenerates. Writes only ever happen from the
-- Edge Function using the service-role key, which bypasses RLS entirely —
-- the only policy needed here is public read.

insert into storage.buckets (id, name, public)
values ('scene-images', 'scene-images', true)
on conflict (id) do nothing;

create policy "public read scene images" on storage.objects
  for select using (bucket_id = 'scene-images');
