-- Tabla dedicada de zonas de peligro para experiencia AR
create extension if not exists "pgcrypto";

create table if not exists danger_zones (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  specific_dangers text default '' not null,
  danger_level text not null check (danger_level in ('high', 'medium', 'low')),
  precautions text default '' not null,
  recommendations text default '' not null,
  latitude double precision not null,
  longitude double precision not null,
  radius double precision not null default 100,
  altitude double precision not null default 0,
  overlay_height double precision not null default 20,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table danger_zones enable row level security;

create policy "Permitir lectura de zonas de peligro" on danger_zones for select to anon, authenticated using (true);
create policy "Permitir inserción de zonas de peligro" on danger_zones for insert to authenticated with check (true);
create policy "Permitir actualización de zonas de peligro" on danger_zones for update to authenticated using (true) with check (true);

create index if not exists idx_danger_zones_level on danger_zones(danger_level);
create index if not exists idx_danger_zones_created_at on danger_zones(created_at desc);
create index if not exists idx_danger_zones_location on danger_zones(latitude, longitude);

-- Actualizar updated_at automáticamente
create or replace function set_danger_zones_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_danger_zones_updated_at on danger_zones;
create trigger trg_danger_zones_updated_at
before update on danger_zones
for each row execute function set_danger_zones_updated_at();
