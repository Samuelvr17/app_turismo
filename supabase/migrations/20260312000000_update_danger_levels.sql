-- Migración para actualizar la restricción check y mapear nivel medio a monitoreado
ALTER TABLE danger_zones DROP CONSTRAINT IF EXISTS danger_zones_danger_level_check;

UPDATE danger_zones 
SET danger_level = 'monitored' 
WHERE danger_level = 'medium';

-- Add the new constraint
ALTER TABLE danger_zones 
ADD CONSTRAINT danger_zones_danger_level_check 
CHECK (danger_level IN ('high', 'massMovement', 'monitored', 'low'));
