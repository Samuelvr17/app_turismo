-- Agrega punto de deslizamiento en Vereda La Argentina
-- Ubicación original: 4°12'05.53"N 73°38'12.21"W
-- Conversión decimal: 4.201536, -73.636725

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
  'Zona de Deslizamiento',
  'Esta ladera presenta procesos de erosión y deslizamiento causados por las lluvias, la fuerza del río y la pérdida de vegetación. El terreno puede seguir deteriorándose con el tiempo, aumentando el riesgo de inundación en la vereda.',
  'Observe únicamente desde el puente o zonas seguras. No acercarse a la base de la ladera. Evitar la zona durante lluvias fuertes.',
  'Posible caída de tierra y rocas.',
  4.201536,
  -73.636725,
  300.0
from danger_zones
where lower(title) like lower('%Vereda%La Argentina%')
limit 1;
