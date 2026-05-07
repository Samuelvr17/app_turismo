-- Corrige la implementación: los puntos con niveles de riesgo distintos deben ser Danger Zones
-- Primero eliminamos los puntos agregados previamente (si existen)
delete from danger_zone_points 
where title in ('Zona de Deslizamiento', 'Portal Ruta del Agua');

-- Agregamos 'Zona de Deslizamiento' como una zona individual (Nivel Naranja/Masas)
insert into danger_zones (
  title,
  description,
  specific_dangers,
  danger_level,
  precautions,
  recommendations,
  latitude,
  longitude,
  radius
) values (
  'Zona de Deslizamiento - Argentina',
  'Esta ladera presenta procesos de erosión y deslizamiento causados por las lluvias, la fuerza del río y la pérdida de vegetación. El terreno puede seguir deteriorándose con el tiempo, aumentando el riesgo de inundación en la vereda.',
  'Procesos de erosión y deslizamiento activo.',
  'massMovement',
  'Observe únicamente desde el puente o zonas seguras. No acercarse a la base de la ladera. Evitar la zona durante lluvias fuertes.',
  'Posible caída de tierra y rocas.',
  4.201536,
  -73.636725,
  300.0
);

-- Agregamos 'Portal Ruta del Agua' como una zona individual (Nivel Verde/Bajo)
insert into danger_zones (
  title,
  description,
  specific_dangers,
  danger_level,
  precautions,
  recommendations,
  latitude,
  longitude,
  radius
) values (
  'Portal Ruta del Agua',
  'Punto de inicio de la Ruta del Agua, un recorrido ecoturístico entre senderos, cascadas y miradores naturales del piedemonte de Villavicencio.' || E'\n\n' ||
  '📍 Cascada Palmichal' || E'\n' ||
  '🥾 7.2 km | ⏱️ 2h | ⛰️ Alta' || E'\n\n' ||
  '📍 Mirador Ruta del Agua' || E'\n' ||
  '🥾 3.6 km | ⏱️ 50 min | ⛰️ Media/Baja',
  'Punto de inicio ecoturístico.',
  'low',
  'Manténgase en los senderos señalizados. No dejar residuos en la zona. Use calzado adecuado para terreno húmedo.',
  'Respete la fauna y flora del recorrido.',
  4.202056,
  -73.64,
  10.0
);
