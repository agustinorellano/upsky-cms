-- UP SKY CMS · Plan Crecimiento · 2/3 · Publicación programada
-- Cada elemento puede traer en "data" dos fechas opcionales:
--   publicar_desde  -> antes de esa fecha NO se ve en el sitio
--   ocultar_desde   -> desde esa fecha deja de verse
-- La regla vive en la política de lectura pública: no hace falta ninguna tarea programada.
-- Los elementos sin fechas se comportan exactamente igual que antes.

create or replace function public.safe_ts(t text) returns timestamptz
language plpgsql stable set search_path = public as $$
begin
  if t is null or t = '' then return null; end if;
  return t::timestamptz;
exception when others then
  return null;   -- una fecha mal escrita nunca rompe la lectura del sitio
end $$;

drop policy if exists "lectura publica" on public.items;
create policy "lectura publica" on public.items for select to anon, authenticated
using (
  active = true
  and coalesce(public.safe_ts(data ->> 'publicar_desde'), '-infinity'::timestamptz) <= now()
  and coalesce(public.safe_ts(data ->> 'ocultar_desde'),  'infinity'::timestamptz)  >  now()
);
