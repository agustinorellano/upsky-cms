-- UP SKY CMS · Fotos y videos del sitio
-- Sección "sitio": lugares fijos de la web (portadas, banners, video del producto) con la foto actual cargada.
-- Además guarda en cada producto y precio por mayor las fotos que el sitio ya usa.
alter table public.items drop constraint if exists items_section_check;
alter table public.items add constraint items_section_check
  check (section in ('productos','mayorista','pasos_negocios','eventos','promos','comunidad','sitio'));

insert into public.items (section, position, active, data)
select 'sitio', v.pos, true, v.d::jsonb from (values
 (0, '{"slot":"inicio_hero","donde":"Inicio","nombre":"Foto principal","imagen_1":"assets/hero-energia.webp"}'),
 (1, '{"slot":"negocios_hero","donde":"Para negocios","nombre":"Foto del banner","imagen_1":"assets/negocios-hero.webp"}'),
 (2, '{"slot":"producto_video","donde":"Producto","nombre":"Video principal","video":"assets/story-sabor-bottle.mp4","portada":"assets/story-sabor-bottle-poster.jpg","imagen_1":"assets/story-sabor-bottle.jpg"}'),
 (3, '{"slot":"producto_ingredientes","donde":"Producto","nombre":"Foto de ingredientes","imagen_1":"assets/ingredientes-cap-splash.jpg"}'),
 (4, '{"slot":"producto_momento_1","donde":"Producto","nombre":"Momento 1 · Energía","imagen_1":"assets/moment-energia-gym.webp"}'),
 (5, '{"slot":"producto_momento_2","donde":"Producto","nombre":"Momento 2 · Enfoque","imagen_1":"assets/moment-fitness-2.jpg"}'),
 (6, '{"slot":"producto_momento_3","donde":"Producto","nombre":"Momento 3 · Rendimiento","imagen_1":"assets/moment-fitness.jpg"}')
) as v(pos, d)
where not exists (select 1 from public.items where section = 'sitio');

update public.items set data = data || '{"imagen_1":"assets/pack-energizante.webp"}'::jsonb
 where section in ('productos','mayorista') and data->>'nombre' in ('1 pack de energizante','30 packs de energizante') and not (data ? 'imagen_1');
update public.items set data = data || '{"imagen_1":"assets/vaso-negro-foto.webp","imagen_2":"assets/vaso-rosa-foto.webp"}'::jsonb
 where section = 'productos' and data->>'tipo' = 'Vaso' and not (data ? 'imagen_1');
update public.items set data = data || '{"imagen_1":"assets/remera-frente.webp","imagen_2":"assets/remera-espalda.webp"}'::jsonb
 where section = 'productos' and data->>'tipo' = 'Remera' and not (data ? 'imagen_1');
