-- Agrega columna danger_level a danger_zone_points y organiza puntos de Vereda Argentina
-- 1. Agregar columna danger_level si no existe
do $$
begin
  if not exists (select 1 from information_schema.columns 
                 where table_name = 'danger_zone_points' 
                 and column_name = 'danger_level') then
    alter table danger_zone_points add column danger_level text;
  end if;
end $$;

-- 2. Limpiar puntos existentes para evitar duplicados al re-insertar
delete from danger_zone_points 
where title in ('Portal Ruta del Agua', 'Zona de Deslizamiento - Argentina');

-- 3. Insertar "Portal Ruta del Agua" como punto de la Vereda La Argentina
insert into danger_zone_points (
  danger_zone_id,
  title,
  description,
  precautions,
  recommendations,
  latitude,
  longitude,
  radius,
  danger_level
)
select
  id,
  'Portal Ruta del Agua',
  'Punto de inicio de la Ruta del Agua, un recorrido ecoturístico entre senderos, cascadas y miradores naturales del piedemonte de Villavicencio.' || E'\n\n' ||
  '📍 Cascada Palmichal' || E'\n' ||
  '🥾 7.2 km | ⏱️ 2h | ⛰️ Alta' || E'\n\n' ||
  '📍 Mirador Ruta del Agua' || E'\n' ||
  '🥾 3.6 km | ⏱️ 50 min | ⛰️ Media/Baja',
  'Manténgase en los senderos señalizados. No dejar residuos en la zona. Use calzado adecuado para terreno húmedo.',
  'Respete la fauna y flora del recorrido.',
  4.202056,
  -73.64,
  10.0,
  'low'
from danger_zones
where lower(title) = lower('Vereda La Argentina - Riesgos')
limit 1;

-- 4. Insertar "Zona de Deslizamiento - Argentina" como punto de la Vereda La Argentina
insert into danger_zone_points (
  danger_zone_id,
  title,
  description,
  precautions,
  recommendations,
  latitude,
  longitude,
  radius,
  danger_level
)
select
  id,
  'Zona de Deslizamiento - Argentina',
  'Esta ladera presenta procesos de erosión y deslizamiento causados por las lluvias, la fuerza del río y la pérdida de vegetación. El terreno puede seguir deteriorándose con el tiempo, aumentando el riesgo de inundación en la vereda.',
  'Observe únicamente desde el puente o zonas seguras. No acercarse a la base de la ladera. Evitar la zona durante lluvias fuertes.',
  'Posible caída de tierra y rocas.',
  4.201536,
  -73.636725,
  300.0,
  'massMovement'
from danger_zones
where lower(title) = lower('Vereda La Argentina - Riesgos')
limit 1;

-- 5. Eliminar las zonas independientes que se crearon por error
delete from danger_zones 
where title in ('Portal Ruta del Agua', 'Zona de Deslizamiento - Argentina');
