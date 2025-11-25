-- Agrega la zona real Vereda La Argentina con su punto inicial de acceso
create extension if not exists "pgcrypto";

-- Inserción de zona general de peligro
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
  'Vereda La Argentina - Riesgos',
  'Riesgo de inundación por desbordamiento del río Guatiquía y deslizamientos en temporada de lluvias. El área combina suelos inestables y cauces fluviales con histórico de crecientes súbitas en temporadas lluviosas.',
  'Inundaciones por río Guatiquía, deslizamientos en taludes, suelos inestables de piedemonte, crecientes súbitas entre abril y noviembre',
  'medium',
  'Evitar transitar durante o después de lluvias intensas. Mantenerse alejado de taludes y laderas inestables. Las zonas inundables están identificadas pero no siempre señalizadas. No acercarse a orillas del río cuando esté crecido.',
  'Consultar pronóstico del clima antes de visitar, especialmente entre abril y noviembre. Informar a alguien tu ruta y hora estimada de regreso, la señal celular puede ser intermitente. Usar calzado apropiado, las vías rurales pueden volverse intransitables durante emergencias climáticas.',
  4.202102,
  -73.640033,
  500.0,
  0,
  20
);

-- Punto específico inicial asociado a la Vereda La Argentina
insert into danger_zone_points (
  danger_zone_id,
  title,
  description,
  precautions,
  recommendations,
  latitude,
  longitude
)
select
  id,
  'Acceso Principal Vereda Argentina',
  'Riesgo de inundación por desbordamiento del río Guatiquía y deslizamientos en temporada de lluvias. El área combina suelos inestables y cauces fluviales.',
  'Evita transitar por la zona durante o inmediatamente después de lluvias intensas. Mantente alejado de taludes y laderas inestables en la vía de acceso. Las zonas inundables están identificadas pero no siempre señalizadas.',
  'Consulta el pronóstico del clima antes de visitar la zona, especialmente entre abril y noviembre. Informa a alguien tu ruta y hora estimada de regreso. La señal celular puede ser intermitente. Usa calzado apropiado. Las vías rurales pueden volverse intransitables durante emergencias climáticas.',
  4.202102,
  -73.640033
from danger_zones
where lower(title) = lower('Vereda La Argentina - Riesgos')
limit 1;
