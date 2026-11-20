-- UP SKY CMS · Comunidad · videos
-- 1) Nueva sección "comunidad" en la tabla de contenido.
-- 2) Bucket público "upsky-videos" (hasta 30 MB por video; MP4, WebM o MOV).
-- 3) El equipo (administradores y editores) puede subir, cambiar y borrar videos. El público solo los ve.
alter table public.items drop constraint if exists items_section_check;
alter table public.items add constraint items_section_check
  check (section in ('productos','mayorista','pasos_negocios','eventos','promos','comunidad'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('upsky-videos', 'upsky-videos', true, 31457280, array['video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set public = true, file_size_limit = 31457280,
  allowed_mime_types = array['video/mp4','video/webm','video/quicktime'];

drop policy if exists "videos equipo" on storage.objects;
create policy "videos equipo" on storage.objects for all to authenticated
  using (bucket_id = 'upsky-videos' and public.is_editor())
  with check (bucket_id = 'upsky-videos' and public.is_editor());
