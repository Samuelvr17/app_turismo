-- Actualiza el punto de prueba 'Condominio Santana' con la información de 'Portal Ruta del Agua'
-- Se mantiene la ubicación original de Santana para que el usuario pueda seguir probando en su entorno local
UPDATE danger_zones
SET 
  description = 'Punto de inicio de la Ruta del Agua, un recorrido ecoturístico entre senderos, cascadas y miradores naturales del piedemonte de Villavicencio.' || E'\n\n' ||
  '📍 Cascada Palmichal' || E'\n' ||
  '🥾 7.2 km | ⏱️ 2h | ⛰️ Alta' || E'\n\n' ||
  '📍 Mirador Ruta del Agua' || E'\n' ||
  '🥾 3.6 km | ⏱️ 50 min | ⛰️ Media/Baja',
  specific_dangers = 'Punto de inicio ecoturístico (Prueba).',
  danger_level = 'low',
  precautions = 'Manténgase en los senderos señalizados. No dejar residuos en la zona. Use calzado adecuado para terreno húmedo.',
  recommendations = 'Respete la fauna y flora del recorrido.',
  radius = 10.0
WHERE lower(title) = lower('Condominio Santana');

-- También actualizamos el título si el usuario quiere que sea idéntico
UPDATE danger_zones
SET title = 'Portal Ruta del Agua (Prueba Santana)'
WHERE lower(title) = lower('Condominio Santana');
