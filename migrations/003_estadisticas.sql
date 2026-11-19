-- UP SKY CMS · Plan Crecimiento · 3/3 · Estadísticas (sin datos personales)
-- El sitio registra: visitas ("view"), clics en WhatsApp ("whatsapp") y "agregar al carrito" ("cart").
-- Solo guarda página, dispositivo y un identificador aleatorio de la visita. Sin cookies, sin IP, sin nombres.

create table if not exists public.analytics_events (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  type        text not null check (type in ('view','whatsapp','cart')),
  page        text not null check (char_length(page) <= 80),
  target      text check (target is null or char_length(target) <= 120),
  session     text not null check (char_length(session) between 8 and 40),
  device      text check (device in ('mobile','desktop'))
);
create index if not exists analytics_events_created on public.analytics_events (created_at desc);

alter table public.analytics_events enable row level security;
-- El sitio público solo puede AGREGAR eventos; no puede leer, cambiar ni borrar.
drop policy if exists "sitio registra eventos" on public.analytics_events;
create policy "sitio registra eventos" on public.analytics_events for insert to anon, authenticated with check (true);
drop policy if exists "admin lee eventos" on public.analytics_events;
create policy "admin lee eventos" on public.analytics_events for select to authenticated using (public.is_admin());
revoke update, delete, truncate on public.analytics_events from anon, authenticated;

-- Resumen para el panel (solo administrador).
create or replace function public.analytics_summary(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d int := least(greatest(coalesce(p_days, 30), 1), 365);
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 30), 1), 365));
  res jsonb;
begin
  if not public.is_admin() then raise exception 'no autorizado' using errcode = '42501'; end if;

  select jsonb_build_object(
    'days', d,
    'views',    count(*) filter (where type = 'view'),
    'visitors', count(distinct session) filter (where type = 'view'),
    'whatsapp', count(*) filter (where type = 'whatsapp'),
    'cart',     count(*) filter (where type = 'cart')
  ) into res from public.analytics_events where created_at >= since;

  return res || jsonb_build_object(
    'daily', coalesce((select jsonb_agg(jsonb_build_object('d', day, 'views', v, 'whatsapp', w) order by day)
      from (select (created_at at time zone 'America/Argentina/Buenos_Aires')::date as day,
                   count(*) filter (where type = 'view') as v, count(*) filter (where type = 'whatsapp') as w
            from public.analytics_events where created_at >= since group by 1) t), '[]'::jsonb),
    'pages', coalesce((select jsonb_agg(jsonb_build_object('name', page, 'n', n) order by n desc)
      from (select page, count(*) n from public.analytics_events where type = 'view' and created_at >= since group by 1 order by 2 desc limit 8) t), '[]'::jsonb),
    'products', coalesce((select jsonb_agg(jsonb_build_object('name', target, 'n', n) order by n desc)
      from (select target, count(*) n from public.analytics_events where type = 'cart' and target is not null and created_at >= since group by 1 order by 2 desc limit 8) t), '[]'::jsonb),
    'devices', coalesce((select jsonb_agg(jsonb_build_object('name', device, 'n', n) order by n desc)
      from (select coalesce(device, 'desconocido') as device, count(*) n from public.analytics_events where type = 'view' and created_at >= since group by 1) t), '[]'::jsonb)
  );
end $$;
revoke all on function public.analytics_summary(int) from public, anon;
grant execute on function public.analytics_summary(int) to authenticated;
