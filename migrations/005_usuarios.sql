-- UP SKY CMS · Plan Crecimiento · 5 · Usuarios con roles (hasta 3)
-- Roles:
--   admin  -> todo: contenido, estadísticas, historial, equipo y plan.
--   editor -> contenido, imágenes, estadísticas e historial. No gestiona el equipo ni el plan.
-- Quién puede entrar lo define la tabla team_members (lista de emails permitidos).
-- Las cuentas las crea la función "team" de Supabase (el administrador elige la contraseña inicial,
-- sin depender del correo). La cuenta de soporte (is_support) no cuenta para el límite de 3.
-- IMPORTANTE: el administrador actual se carga ANTES de cambiar las funciones, para no quedar afuera.

-- 1) Equipo
create table if not exists public.team_members (
  email       text primary key,
  role        text not null check (role in ('admin','editor')),
  name        text,
  invited_by  text,
  is_support  boolean not null default false,   -- acceso de soporte de la agencia: no cuenta para el límite y el cliente no lo cambia
  created_at  timestamptz not null default now(),
  constraint team_members_email_ok check (email = lower(email) and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')
);
alter table public.team_members enable row level security;

insert into public.team_members (email, role, name, is_support)
values ('agustinorellanogomez@gmail.com', 'admin', 'Soporte Conectado', true)
on conflict (email) do nothing;

-- 2) Funciones de rol (reemplazan a is_admin basada en un email fijo)
create or replace function public.team_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.team_members where email = lower(coalesce(auth.jwt() ->> 'email', ''))
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.team_role(), '') = 'admin'
$$;
create or replace function public.is_editor() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.team_role(), '') in ('admin', 'editor')
$$;
revoke all on function public.team_role() from public, anon;
revoke all on function public.is_editor()  from public, anon;
grant execute on function public.team_role() to authenticated;
grant execute on function public.is_editor() to authenticated;

-- 3) Contenido: pueden leer todo y escribir administradores y editores
drop policy if exists "admin lee todo" on public.items;
drop policy if exists "admin inserta" on public.items;
drop policy if exists "admin actualiza" on public.items;
drop policy if exists "admin borra" on public.items;
create policy "equipo lee todo"  on public.items for select to authenticated using (public.is_editor());
create policy "equipo inserta"   on public.items for insert to authenticated with check (public.is_editor());
create policy "equipo actualiza" on public.items for update to authenticated using (public.is_editor()) with check (public.is_editor());
create policy "equipo borra"     on public.items for delete to authenticated using (public.is_editor());

drop policy if exists "admin lee historial" on public.item_history;
create policy "equipo lee historial" on public.item_history for select to authenticated using (public.is_editor());

drop policy if exists "admin lee eventos" on public.analytics_events;
create policy "equipo lee eventos" on public.analytics_events for select to authenticated using (public.is_editor());

drop policy if exists "imagenes admin" on storage.objects;
create policy "imagenes equipo" on storage.objects for all to authenticated
  using (bucket_id = 'upsky-images' and public.is_editor()) with check (bucket_id = 'upsky-images' and public.is_editor());

create or replace function public.analytics_summary(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  d int := least(greatest(coalesce(p_days, 30), 1), 365);
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 30), 1), 365));
  res jsonb;
begin
  if not public.is_editor() then raise exception 'no autorizado' using errcode = '42501'; end if;

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

-- 4) Equipo: cada persona ve su propia fila; solo el administrador ve y cambia el resto.
--    Las altas las hace la función del servidor (clave de servicio), no el navegador.
drop policy if exists "equipo ve su fila" on public.team_members;
create policy "equipo ve su fila" on public.team_members for select to authenticated
  using (public.is_admin() or email = lower(coalesce(auth.jwt() ->> 'email', '')));
drop policy if exists "admin cambia roles" on public.team_members;
create policy "admin cambia roles" on public.team_members for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "admin quita personas" on public.team_members;
create policy "admin quita personas" on public.team_members for delete to authenticated using (public.is_admin());

-- 5) Reglas del equipo: máximo 3 personas (sin contar soporte), email fijo, siempre al menos un administrador,
--    y el acceso de soporte no lo cambia ni lo quita el cliente (solo se toca desde SQL o con la clave de servicio).
create or replace function public.team_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare from_client boolean := coalesce(auth.jwt() ->> 'role', '') = 'authenticated';
begin
  if tg_op = 'INSERT' then
    if from_client and new.is_support then raise exception 'No se puede crear un acceso de soporte.' using errcode = 'P0001'; end if;
    if not new.is_support and (select count(*) from public.team_members where not is_support) >= 3 then
      raise exception 'El equipo ya tiene 3 usuarios (el máximo del plan).' using errcode = 'P0001';
    end if;
    return new;
  elsif tg_op = 'UPDATE' then
    if new.email <> old.email then raise exception 'El email no se puede cambiar.' using errcode = 'P0001'; end if;
    if from_client and (new.is_support <> old.is_support or (old.is_support and new.role <> old.role)) then
      raise exception 'El acceso de soporte no se puede modificar.' using errcode = 'P0001';
    end if;
    if old.role = 'admin' and new.role <> 'admin'
       and (select count(*) from public.team_members where role = 'admin' and email <> old.email) = 0 then
      raise exception 'Tiene que quedar al menos un administrador.' using errcode = 'P0001';
    end if;
    return new;
  else
    if from_client and old.is_support then raise exception 'El acceso de soporte no se puede quitar.' using errcode = 'P0001'; end if;
    if old.role = 'admin'
       and (select count(*) from public.team_members where role = 'admin' and email <> old.email) = 0 then
      raise exception 'Tiene que quedar al menos un administrador.' using errcode = 'P0001';
    end if;
    return old;
  end if;
end $$;
revoke all on function public.team_guard() from public, anon, authenticated;
drop trigger if exists team_guard on public.team_members;
create trigger team_guard before insert or update or delete on public.team_members
  for each row execute function public.team_guard();
