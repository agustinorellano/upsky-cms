-- UP SKY CMS · Plan Crecimiento · 1/3 · Historial de cambios con deshacer
-- Guarda una copia de cada cambio de contenido (alta, edición, baja) para poder verlo y deshacerlo.
-- Reordenar (cambiar posición) NO se registra.

create table if not exists public.item_history (
  id          bigint generated always as identity primary key,
  item_id     uuid not null,
  section     text not null,
  action      text not null check (action in ('insert','update','delete')),
  old_data    jsonb,
  new_data    jsonb,
  old_active  boolean,
  new_active  boolean,
  changed_by  text not null default coalesce(auth.jwt() ->> 'email', ''),
  changed_at  timestamptz not null default now()
);
create index if not exists item_history_changed_at on public.item_history (changed_at desc);
create index if not exists item_history_item on public.item_history (item_id, changed_at desc);

alter table public.item_history enable row level security;
-- Solo el administrador puede leer. No hay políticas de escritura: solo escribe el trigger.
drop policy if exists "admin lee historial" on public.item_history;
create policy "admin lee historial" on public.item_history for select to authenticated using (public.is_admin());

create or replace function public.log_item_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.item_history (item_id, section, action, new_data, new_active)
    values (new.id, new.section, 'insert', new.data, new.active);
  elsif tg_op = 'UPDATE' then
    if new.data is distinct from old.data or new.active is distinct from old.active then
      insert into public.item_history (item_id, section, action, old_data, new_data, old_active, new_active)
      values (new.id, new.section, 'update', old.data, new.data, old.active, new.active);
    end if;
  elsif tg_op = 'DELETE' then
    insert into public.item_history (item_id, section, action, old_data, old_active)
    values (old.id, old.section, 'delete', old.data, old.active);
  end if;
  return null;
end $$;
revoke all on function public.log_item_change() from public, anon, authenticated;

drop trigger if exists items_history on public.items;
create trigger items_history after insert or update or delete on public.items
  for each row execute function public.log_item_change();
