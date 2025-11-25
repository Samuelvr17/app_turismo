-- Zona de prueba técnica para validación AR en residencia
create extension if not exists "pgcrypto";

-- Inserción de zona general de prueba
insert into danger_zones (
  title,
  description,
  specific_dangers,
  danger_level,
  precautions,
  recommendations,
  latitude,
  longitude,
  radius,
  altitude,
  overlay_height
) values (
  'Casa ivan- Zona de Prueba AR',
  'Zona residencial de prueba para demostración del sistema AR. Área utilizada para validar funcionamiento de detección GPS, cálculo de bearing y activación de overlays en entorno controlado.',
  'Zona de prueba técnica. Sin peligros reales. Utilizada para verificar precisión de sensores y algoritmos de posicionamiento AR.',
  'low',
  'Esta es una zona de prueba para validación técnica del sistema. No representa peligros reales. Mantén el GPS activo para verificar precisión de detección.',
  'Caminar alrededor del perímetro para probar detección de puntos desde diferentes ángulos. Verificar que bearing relativo se actualiza correctamente. Confirmar activación de overlay al apuntar hacia coordenadas específicas.',
  4.138283,
  -73.622998,
  100.0,
  0,
  20
);

-- Punto específico de prueba dentro de la zona
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
  'Entrada Principal - Punto de Prueba',
  'Punto de entrada utilizado para pruebas de precisión AR. Permite validar detección de proximidad y activación de overlay emergente en distancia corta.',
  'Zona de prueba técnica. Verifica que el overlay aparezca al apuntar hacia estas coordenadas con tolerancia de ±20 grados. Confirma cálculo correcto de distancia en tiempo real.',
  'Gira 360° para verificar que bearing relativo se actualiza correctamente. Acércate y aléjate para confirmar threshold de activación (200m). Prueba en diferentes condiciones de señal GPS para validar estabilidad.',
  4.138418,
  -73.623517,
  30.0
from danger_zones
where lower(title) = lower('Casa ivan- Zona de Prueba AR')
limit 1;
