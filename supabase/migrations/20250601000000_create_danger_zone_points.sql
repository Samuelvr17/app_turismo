-- Tabla de puntos específicos dentro de una zona de peligro
create extension if not exists "pgcrypto";

create table if not exists danger_zone_points (
  id uuid primary key default gen_random_uuid(),
  danger_zone_id uuid not null references danger_zones(id) on delete cascade,
  title text not null,
  description text not null default '',
  precautions text not null default '',
  recommendations text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  radius double precision not null default 30,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table danger_zone_points enable row level security;

create policy "Permitir lectura de puntos de zonas" on danger_zone_points for select to anon, authenticated using (true);
create policy "Permitir inserción de puntos de zonas" on danger_zone_points for insert to authenticated with check (true);
create policy "Permitir actualización de puntos de zonas" on danger_zone_points for update to authenticated using (true) with check (true);

create index if not exists idx_danger_zone_points_zone on danger_zone_points(danger_zone_id);
create index if not exists idx_danger_zone_points_location on danger_zone_points(latitude, longitude);
create index if not exists idx_danger_zone_points_created_at on danger_zone_points(created_at desc);

-- Actualizar updated_at automáticamente
create or replace function set_danger_zone_points_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_danger_zone_points_updated_at on danger_zone_points;
create trigger trg_danger_zone_points_updated_at
before update on danger_zone_points
for each row execute function set_danger_zone_points_updated_at();

-- Datos de prueba para Condominio Santana
insert into danger_zone_points (
  danger_zone_id,
  title,
  description,
  precautions,
  recommendations,
  latitude,
  longitude,
  radius
)
select
  id,
  'Punto Norte',
  'Deslizamiento activo en el sector norte del condominio. Evita estacionar vehículos en esta ladera.',
  'No te acerques al talud y sigue las señales de evacuación del condominio.',
  'Reporta cualquier movimiento inusual del terreno a la administración.',
  4.11119758583947,
  -73.62955162125496,
  30
from danger_zones
where lower(title) = lower('Condominio Santana')
limit 1;

insert into danger_zone_points (
  danger_zone_id,
  title,
  description,
  precautions,
  recommendations,
  latitude,
  longitude,
  radius
)
select
  id,
  'Punto Este',
  'Zona con riesgo de inundación cerca del límite oriental. El terreno puede anegarse rápidamente.',
  'Evita transitar a pie o en vehículo cuando el nivel del agua suba.',
  'Usa rutas alternativas señalizadas por la administración en caso de lluvias fuertes.',
  4.11139409911947,
  -73.6304420454673,
  30
from danger_zones
where lower(title) = lower('Condominio Santana')
limit 1;
