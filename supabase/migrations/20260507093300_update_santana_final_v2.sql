-- Segunda actualización para 'Condominio Santana' para forzar el cambio en Supabase
-- Usa el formato multilínea exacto solicitado
UPDATE danger_zones
SET 
  description = 'Punto de inicio de la Ruta del Agua, un recorrido ecoturístico entre senderos, cascadas y miradores naturales del piedemonte de Villavicencio.' || E'\n\n' ||
  '📍 Cascada Palmichal' || E'\n' ||
  '🥾 7.2 km' || E'\n' ||
  '⏱️ aprox 2 horas' || E'\n' ||
  '⛰️ Dificultad alta' || E'\n\n' ||
  '📍 Mirador Ruta del Agua' || E'\n' ||
  '🥾 3.6 km' || E'\n' ||
  '⏱️ aprox 50 min' || E'\n' ||
  '⛰️ Dificultad media - baja',
  specific_dangers = 'Punto de inicio ecoturístico (Prueba).',
  danger_level = 'low',
  precautions = 'Manténgase en los senderos señalizados. No dejar residuos en la zona. Use calzado adecuado para terreno húmedo.',
  recommendations = 'Respete la fauna y flora del recorrido.',
  radius = 10.0
WHERE lower(title) LIKE '%santana%';
