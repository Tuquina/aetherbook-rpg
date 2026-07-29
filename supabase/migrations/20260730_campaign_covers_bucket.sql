-- Public bucket for campaign-editor cover images (V2 design prototype §9f:
-- "Imagen de portada"), uploaded directly by the author from the client —
-- unlike scene-images (20260724), there's no Edge Function/service-role
-- writer here, so RLS has to do real work: an author may only write under
-- their own uid-prefixed folder, and anyone may read (a published cover
-- needs to be visible to every reader, and drafting needs to preview its own
-- upload immediately).

insert into storage.buckets (id, name, public)
values ('campaign-covers', 'campaign-covers', true)
on conflict (id) do nothing;

create policy "public read campaign covers" on storage.objects
  for select using (bucket_id = 'campaign-covers');

create policy "authors write own campaign covers" on storage.objects
  for insert with check (
    bucket_id = 'campaign-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "authors update own campaign covers" on storage.objects
  for update using (
    bucket_id = 'campaign-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "authors delete own campaign covers" on storage.objects
  for delete using (
    bucket_id = 'campaign-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
