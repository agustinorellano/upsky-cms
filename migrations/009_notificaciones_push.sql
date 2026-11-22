-- UP SKY CMS · Notificaciones push
-- Cada persona del equipo activa las notificaciones en su dispositivo (celular o computadora).
-- Avisos: clics a WhatsApp, productos agregados al carrito, y la agenda (evento de mañana,
-- promoción que termina en 24 h, publicación programada que salió).
-- Las claves de cifrado (VAPID) las genera y guarda la función "push" en push_config, que ningún
-- usuario del panel puede leer (solo la función, con la clave de servicio).

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

-- 1) Configuración privada de la función (sin políticas = solo clave de servicio)
create table if not exists public.push_config (
  id            int primary key default 1 check (id = 1),
  vapid_public  text,
  vapid_private text,
  secret        text not null default encode(gen_random_bytes(24), 'hex')
);
alter table public.push_config enable row level security;
revoke all on public.push_config from anon, authenticated;
insert into public.push_config (id) values (1) on conflict (id) do nothing;

-- 2) Dispositivos suscriptos
create table if not exists public.push_subscriptions (
  endpoint   text primary key check (endpoint like 'https://%' and length(endpoint) < 1200),
  email      text not null check (email = lower(email)),
  p256dh     text not null,
  auth       text not null,
  prefs      jsonb not null default '{"whatsapp":true,"cart":true,"agenda":true}',
  created_at timestamptz not null default now()
);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon;
drop policy if exists "push ve los suyos" on public.push_subscriptions;
drop policy if exists "push crea el suyo" on public.push_subscriptions;
drop policy if exists "push cambia el suyo" on public.push_subscriptions;
drop policy if exists "push borra el suyo" on public.push_subscriptions;
create policy "push ve los suyos"   on public.push_subscriptions for select to authenticated
  using (public.is_editor() and email = lower(coalesce(auth.jwt() ->> 'email', '')));
create policy "push crea el suyo"   on public.push_subscriptions for insert to authenticated
  with check (public.is_editor() and email = lower(coalesce(auth.jwt() ->> 'email', '')));
create policy "push cambia el suyo" on public.push_subscriptions for update to authenticated
  using (public.is_editor() and email = lower(coalesce(auth.jwt() ->> 'email', '')))
  with check (public.is_editor() and email = lower(coalesce(auth.jwt() ->> 'email', '')));
create policy "push borra el suyo"  on public.push_subscriptions for delete to authenticated
  using (public.is_editor() and email = lower(coalesce(auth.jwt() ->> 'email', '')));

-- 3) Registro de avisos enviados (evita repetir y limita la frecuencia)
create table if not exists public.push_log (
  key     text primary key,
  kind    text not null,
  sent_at timestamptz not null default now()
);
create index if not exists push_log_kind_sent on public.push_log (kind, sent_at desc);
alter table public.push_log enable row level security;
revoke all on public.push_log from anon, authenticated;

-- 4) Aviso por actividad del sitio: máximo uno cada 15 minutos por tipo, y nunca bloquea al visitante
create or replace function public.push_on_event() returns trigger
language plpgsql security definer set search_path = public, extensions, net as $$
declare sec text;
begin
  if new.type not in ('whatsapp', 'cart') then return new; end if;
  if not exists (select 1 from public.push_subscriptions) then return new; end if;
  if exists (select 1 from public.push_log where kind = new.type and sent_at > now() - interval '15 minutes') then return new; end if;
  select secret into sec from public.push_config where id = 1;
  if sec is null then return new; end if;
  insert into public.push_log (key, kind) values (new.type || ':' || extract(epoch from clock_timestamp())::bigint, new.type) on conflict do nothing;
  perform net.http_post(
    url := 'https://stwyjbxmkwgwjwmctpki.supabase.co/functions/v1/push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', sec),
    body := jsonb_build_object('action', 'event', 'kind', new.type, 'target', new.target));
  return new;
exception when others then
  return new;
end $$;
revoke all on function public.push_on_event() from public, anon, authenticated;
drop trigger if exists push_on_event on public.analytics_events;
create trigger push_on_event after insert on public.analytics_events
  for each row execute function public.push_on_event();

-- 5) Agenda: una vez por hora (minuto 5) la función revisa eventos, promociones y publicaciones
create or replace function public.push_agenda() returns void
language plpgsql security definer set search_path = public, extensions, net as $$
declare sec text;
begin
  if not exists (select 1 from public.push_subscriptions) then return; end if;
  select secret into sec from public.push_config where id = 1;
  if sec is null then return; end if;
  perform net.http_post(
    url := 'https://stwyjbxmkwgwjwmctpki.supabase.co/functions/v1/push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', sec),
    body := '{"action":"agenda"}'::jsonb);
end $$;
revoke all on function public.push_agenda() from public, anon, authenticated;
select cron.unschedule('push-agenda') where exists (select 1 from cron.job where jobname = 'push-agenda');
select cron.schedule('push-agenda', '5 * * * *', 'select public.push_agenda()');
