-- UP SKY CMS · Competencia
-- Competidores (hasta 5) con sus links, y "fotos" con fecha de los números que carga el equipo.
-- La comparativa se calcula en el panel con esos números (sin IA). La parte con IA se suma después
-- y usará su propio cupo mensual.
-- UP SKY es la fila propia (is_own) y no cuenta para el límite de 5.

create table if not exists public.competitors (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 60),
  color      text not null default '#6366f1' check (color ~ '^#[0-9a-fA-F]{6}$'),
  is_own     boolean not null default false,
  links      jsonb not null default '[]' check (jsonb_typeof(links) = 'array' and jsonb_array_length(links) <= 8),
  notes      text check (notes is null or char_length(notes) <= 400),
  position   int not null default 0,
  created_at timestamptz not null default now()
);
create unique index if not exists competitors_one_own on public.competitors ((true)) where is_own;

create table if not exists public.competitor_snapshots (
  id            uuid primary key default gen_random_uuid(),
  competitor_id uuid not null references public.competitors (id) on delete cascade,
  taken_on      date not null default current_date,
  metrics       jsonb not null default '{}' check (jsonb_typeof(metrics) = 'object'),
  source        text not null default 'manual' check (source in ('manual', 'ia')),
  created_by    text,
  created_at    timestamptz not null default now(),
  unique (competitor_id, taken_on)
);
create index if not exists competitor_snapshots_by_comp on public.competitor_snapshots (competitor_id, taken_on desc);

alter table public.competitors enable row level security;
alter table public.competitor_snapshots enable row level security;
revoke all on public.competitors, public.competitor_snapshots from anon;
drop policy if exists "equipo gestiona competidores" on public.competitors;
drop policy if exists "equipo gestiona numeros" on public.competitor_snapshots;
create policy "equipo gestiona competidores" on public.competitors for all to authenticated
  using (public.is_editor()) with check (public.is_editor());
create policy "equipo gestiona numeros" on public.competitor_snapshots for all to authenticated
  using (public.is_editor()) with check (public.is_editor());

-- Reglas: máximo 5 competidores (sin contar UP SKY) y links https de redes conocidas
create or replace function public.competitors_guard() returns trigger
language plpgsql set search_path = public as $$
declare l jsonb;
begin
  if tg_op = 'INSERT' and not new.is_own and (select count(*) from public.competitors where not is_own) >= 5 then
    raise exception 'Ya hay 5 competidores (el máximo).' using errcode = 'P0001';
  end if;
  for l in select * from jsonb_array_elements(new.links) loop
    if jsonb_typeof(l) <> 'object'
       or coalesce(l ->> 'url', '') !~ '^https://[^[:space:]]{3,250}$'
       or coalesce(l ->> 'network', '') not in ('instagram','tiktok','facebook','youtube','x','linkedin','web','tienda','otro') then
      raise exception 'Cada link tiene que empezar con https:// y tener una red válida.' using errcode = 'P0001';
    end if;
  end loop;
  return new;
end $$;
drop trigger if exists competitors_guard on public.competitors;
create trigger competitors_guard before insert or update on public.competitors
  for each row execute function public.competitors_guard();

-- Los números: solo claves conocidas y valores numéricos razonables
create or replace function public.competitor_snapshots_guard() returns trigger
language plpgsql set search_path = public as $$
declare k text; v jsonb;
begin
  for k, v in select * from jsonb_each(new.metrics) loop
    if k not in ('ig_followers','tt_followers','fb_followers','yt_subscribers','posts_month','avg_likes','price') then
      raise exception 'Métrica desconocida: %', k using errcode = 'P0001';
    end if;
    if jsonb_typeof(v) <> 'number' or (v #>> '{}')::numeric < 0 or (v #>> '{}')::numeric > 1000000000000 then
      raise exception 'El valor de % tiene que ser un número entre 0 y 1.000.000.000.000.', k using errcode = 'P0001';
    end if;
  end loop;
  new.created_by := coalesce(new.created_by, lower(coalesce(auth.jwt() ->> 'email', '')));
  return new;
end $$;
drop trigger if exists competitor_snapshots_guard on public.competitor_snapshots;
create trigger competitor_snapshots_guard before insert or update on public.competitor_snapshots
  for each row execute function public.competitor_snapshots_guard();

-- Fila propia
insert into public.competitors (name, color, is_own, position)
select 'UP SKY', '#ec1f7a', true, -1
where not exists (select 1 from public.competitors where is_own);
