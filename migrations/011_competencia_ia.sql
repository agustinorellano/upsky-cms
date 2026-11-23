-- UP SKY CMS · Competencia: análisis de contenido con IA
-- El cliente carga hasta 5 competidores (links) y, si quiere, material extra (textos pegados o capturas).
-- Una función de Supabase ("competencia") lee lo que se puede leer, lo analiza con Claude y guarda un
-- informe. Cupo: 2 análisis por mes (se descuenta solo si el análisis sale bien).
-- Los informes y el uso los escribe solo la función (clave de servicio): el panel solo los lee.
-- competitor_snapshots (números cargados a mano) queda sin uso en el panel.

-- 1) Material que carga el cliente (texto pegado o captura)
create table if not exists public.competitor_material (
  id            uuid primary key default gen_random_uuid(),
  competitor_id uuid not null references public.competitors (id) on delete cascade,
  kind          text not null check (kind in ('texto', 'imagen')),
  content       text check (content is null or char_length(content) <= 6000),
  storage_path  text check (storage_path is null or char_length(storage_path) <= 200),
  network       text check (network is null or network in ('instagram','tiktok','facebook','youtube','x','linkedin','web','tienda','otro')),
  note          text check (note is null or char_length(note) <= 200),
  created_by    text,
  created_at    timestamptz not null default now(),
  check ((kind = 'texto' and content is not null and char_length(trim(content)) > 0) or (kind = 'imagen' and storage_path is not null))
);
create index if not exists competitor_material_by_comp on public.competitor_material (competitor_id, created_at desc);
alter table public.competitor_material enable row level security;
revoke all on public.competitor_material from anon;
drop policy if exists "equipo gestiona material" on public.competitor_material;
create policy "equipo gestiona material" on public.competitor_material for all to authenticated
  using (public.is_editor()) with check (public.is_editor());

create or replace function public.competitor_material_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if (select count(*) from public.competitor_material where competitor_id = new.competitor_id) >= 10 then
    raise exception 'Cada competidor admite hasta 10 materiales. Borrá alguno para sumar otro.' using errcode = 'P0001';
  end if;
  new.created_by := coalesce(new.created_by, lower(coalesce(auth.jwt() ->> 'email', '')));
  return new;
end $$;
drop trigger if exists competitor_material_guard on public.competitor_material;
create trigger competitor_material_guard before insert on public.competitor_material
  for each row execute function public.competitor_material_guard();

-- 2) Informes (solo los escribe la función)
create table if not exists public.competitor_reports (
  id          uuid primary key default gen_random_uuid(),
  month       text not null check (month ~ '^[0-9]{4}-[0-9]{2}$'),
  status      text not null default 'running' check (status in ('running', 'done', 'error')),
  data        jsonb,
  usage       jsonb,
  error       text,
  refunded    boolean not null default false,
  created_by  text,
  created_at  timestamptz not null default now(),
  finished_at timestamptz
);
create unique index if not exists competitor_reports_one_running on public.competitor_reports ((true)) where status = 'running';
create index if not exists competitor_reports_by_date on public.competitor_reports (created_at desc);
alter table public.competitor_reports enable row level security;
revoke all on public.competitor_reports from anon;
revoke insert, update, delete on public.competitor_reports from authenticated;
drop policy if exists "equipo lee informes" on public.competitor_reports;
create policy "equipo lee informes" on public.competitor_reports for select to authenticated using (public.is_editor());

-- 3) Cupo mensual de análisis
create table if not exists public.ai_usage (
  month text primary key check (month ~ '^[0-9]{4}-[0-9]{2}$'),
  used  int not null default 0 check (used >= 0),
  bonus int not null default 0 check (bonus >= 0)   -- análisis extra que la agencia le suma a mano
);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from anon;
revoke insert, update, delete on public.ai_usage from authenticated;
drop policy if exists "equipo lee uso" on public.ai_usage;
create policy "equipo lee uso" on public.ai_usage for select to authenticated using (public.is_editor());

-- Reserva atómica: devuelve true si todavía queda cupo en el mes
create or replace function public.ai_reserve(p_month text, p_limit int) returns boolean
language plpgsql security definer set search_path = public as $$
declare ok int;
begin
  insert into public.ai_usage (month) values (p_month) on conflict (month) do nothing;
  update public.ai_usage set used = used + 1 where month = p_month and used < p_limit + bonus;
  get diagnostics ok = row_count;
  return ok = 1;
end $$;
create or replace function public.ai_release(p_month text) returns void
language sql security definer set search_path = public as $$
  update public.ai_usage set used = greatest(used - 1, 0) where month = p_month;
$$;
revoke all on function public.ai_reserve(text, int), public.ai_release(text) from public, anon, authenticated;

-- 4) Capturas: bucket privado
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('upsky-competencia', 'upsky-competencia', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];
drop policy if exists "competencia equipo" on storage.objects;
create policy "competencia equipo" on storage.objects for all to authenticated
  using (bucket_id = 'upsky-competencia' and public.is_editor()) with check (bucket_id = 'upsky-competencia' and public.is_editor());
