/*
  # Migración: Agregar Cascada 3 Colores a Vereda Argentina
  
  1. Propósito
     - Actualizar la lista de puntos de interés de la ruta "Vereda Argentina"
       para incluir la nueva actividad "Cascada 3 Colores".
  2. Ajustes
     - Se actualiza el campo points_of_interest (tipo text[]) de la tabla safe_routes.
*/

UPDATE safe_routes
SET points_of_interest = ARRAY['Ciclismo', 'Caminata', 'Cascada 3 Colores']::text[]
WHERE name = 'Vereda Argentina';
