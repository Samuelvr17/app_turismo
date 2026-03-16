-- Migración para actualizar los niveles de peligro y descripciones de los puntos 1-35
-- Esta migración actualiza tanto el nivel como la descripción detallada.

-- 1. Actualizar niveles y descripción para puntos ROJOS (1-15)
UPDATE danger_zones
SET 
  danger_level = 'high',
  description = 'Alto riesgo o posibilidad de colapso'
WHERE title IN ('Punto 1', 'Punto 2', 'Punto 12', 'Punto 13');

-- 2. Actualizar niveles (Naranja y Amarillo) para los puntos restantes
UPDATE danger_zones
SET danger_level = 'massMovement'
WHERE title IN (
  'Punto 3', 'Punto 5', 'Punto 6', 'Punto 7', 'Punto 8', 'Punto 9', 
  'Punto 16', 'Punto 17', 'Punto 18', 'Punto 20', 'Punto 21', 'Punto 22', 
  'Punto 23', 'Punto 24', 'Punto 25', 'Punto 26', 'Punto 27', 'Punto 28'
);

UPDATE danger_zones
SET danger_level = 'monitored'
WHERE title IN (
  'Punto 4', 'Punto 10', 'Punto 11', 'Punto 14', 'Punto 15', 'Punto 19', 
  'Punto 29', 'Punto 30', 'Punto 31', 'Punto 32', 'Punto 33', 'Punto 34', 'Punto 35'
);

-- 3. Actualizar descripciones detalladas para puntos 16-35

-- Puntos 16 y 17
UPDATE danger_zones 
SET description = 'Asistencia tecnica gestion de riesgo, por deslizamiento sector puente vehicular caño parrado, alcaldia de villavicencio, gobernacion del meta, comunidad y cormacarena, municipio de Villavicencio' 
WHERE title IN ('Punto 16', 'Punto 17');

-- Punto 18
UPDATE danger_zones 
SET description = 'Asistencia Técnica de gestión del riesgo por fenómenos de socavación lateral que afecta principalmente el encerramiento del conjunto residencial San Angel II el cual se localizan en la ronda hídrica del caño Seco sector Doce de Octubre colindante c' 
WHERE title = 'Punto 18';

-- Puntos 19 y 29
UPDATE danger_zones 
SET description = 'Asistencia técnica de gestión del riesgo a puntos críticos a causa de desbordamiento de los caños La Cuerera, caño Parrado, caño Grande, caño Maizaro, caño Pendejo, caño Buque y río Ocoa dentro del casco urbano del municipio de Villavicencio, D' 
WHERE title IN ('Punto 19', 'Punto 29');

-- Puntos 20 al 28
UPDATE danger_zones 
SET description = 'Asistencia tecnica de gestion del riesgo, por deslizamiento y retroceso del talud sector del barrio El Rosal, en el municipio Villavicencio, Departamento del Meta.' 
WHERE title IN ('Punto 20', 'Punto 21', 'Punto 22', 'Punto 23', 'Punto 24', 'Punto 25', 'Punto 26', 'Punto 27', 'Punto 28');

-- Puntos 30 al 34
UPDATE danger_zones 
SET description = 'Asistencia Técnica de gestión del riesgo por desprendimiento de material sector cerro Cristo rey, colindante a la corporación universitaria Minuto de Dios, Municipio de Villavicencio, departamento del Meta.' 
WHERE title IN ('Punto 30', 'Punto 31', 'Punto 32', 'Punto 33', 'Punto 34');

-- Punto 35
UPDATE danger_zones 
SET description = 'Asistencia gestión del riesgo por desperendimiento del talud en el sector del barrio centro, caño parrado, casco urbno municipio de Villavicencio.' 
WHERE title = 'Punto 35';
