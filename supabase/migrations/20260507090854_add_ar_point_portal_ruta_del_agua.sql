-- Agrega punto 'Portal Ruta del Agua' en Vereda La Argentina
-- Ubicación original: 4°12'07.4"N 73°38'24.0"W
-- Conversión decimal: 4.202056, -73.64

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
  'Portal Ruta del Agua',
  'Punto de inicio de la Ruta del Agua, un recorrido ecoturístico entre senderos, cascadas y miradores naturales del piedemonte de Villavicencio.' || E'\n\n' ||
  '📍 Cascada Palmichal' || E'\n' ||
  '🥾 7.2 km' || E'\n' ||
  '⏱️ aprox 2 horas' || E'\n' ||
  '⛰️ Dificultad alta' || E'\n\n' ||
  '📍 Mirador Ruta del Agua' || E'\n' ||
  '🥾 3.6 km' || E'\n' ||
  '⏱️ aprox 50 min' || E'\n' ||
  '⛰️ Dificultad media - baja',
  'Manténgase en los senderos señalizados. No dejar residuos en la zona. Use calzado adecuado para terreno húmedo.',
  'Respete la fauna y flora del recorrido.',
  4.202056,
  -73.64,
  10.0
from danger_zones
where lower(title) like lower('%Vereda%La Argentina%')
limit 1;
