-- UP SKY CMS · Plan Crecimiento · 4 · Promociones
-- Las promociones viven en la misma tabla "items", con section = 'promos'.
-- Sus fechas de inicio y fin usan "publicar_desde" y "ocultar_desde" (ver 002): la base ya
-- decide sola cuándo se ven en el sitio.
-- Este cambio solo amplía la lista de secciones permitidas; no toca ningún dato.

alter table public.items drop constraint if exists items_section_check;
alter table public.items add constraint items_section_check
  check (section in ('productos','mayorista','pasos_negocios','eventos','promos'));
