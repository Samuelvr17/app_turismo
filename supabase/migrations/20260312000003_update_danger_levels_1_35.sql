-- Migración para actualizar los niveles de peligro y descripciones de los puntos 1-35
-- Rojo (high): 1, 2, 12, 13
-- Naranja (massMovement): 3, 5, 6, 7, 8, 9, 16, 17, 18, 20, 21, 22, 23, 24, 25, 26, 27, 28
-- Amarillo (monitored): 4, 10, 11, 14, 15, 19, 29, 30, 31, 32, 33, 34, 35

-- Actualizar niveles y descripción para puntos ROJOS
UPDATE danger_zones
SET 
  danger_level = 'high',
  description = 'Alto riesgo o posibilidad de colapso'
WHERE title IN ('Punto 1', 'Punto 2', 'Punto 12', 'Punto 13');

-- Actualizar niveles para puntos NARANJA
UPDATE danger_zones
SET 
  danger_level = 'massMovement'
WHERE title IN (
  'Punto 3', 'Punto 5', 'Punto 6', 'Punto 7', 'Punto 8', 'Punto 9', 
  'Punto 16', 'Punto 17', 'Punto 18', 'Punto 20', 'Punto 21', 'Punto 22', 
  'Punto 23', 'Punto 24', 'Punto 25', 'Punto 26', 'Punto 27', 'Punto 28'
);

-- Actualizar niveles para puntos AMARILLO
UPDATE danger_zones
SET 
  danger_level = 'monitored'
WHERE title IN (
  'Punto 4', 'Punto 10', 'Punto 11', 'Punto 14', 'Punto 15', 'Punto 19', 
  'Punto 29', 'Punto 30', 'Punto 31', 'Punto 32', 'Punto 33', 'Punto 34', 'Punto 35'
);
