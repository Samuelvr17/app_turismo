/*
  # Migración: Actualizar imágenes de actividades

  1. Propósito
     - Limpiar y actualizar los registros en `activity_images` para las
       nuevas locaciones y actividades usando el Storage en Supabase.
  2. Ajustes
     - Elimina los registros previos de Vereda Buenavista (Miradores, Parapente, Caminata ecológica).
     - Elimina los registros previos de Vereda Argentina (Cascada 3 Colores).
     - Inserta los nuevos registros respetando `display_order`.
*/

-- 1. Eliminar imágenes existentes únicamente para las combinaciones especificadas
DELETE FROM activity_images
WHERE (route_name = 'Vereda Buenavista' AND activity_name = 'Miradores')
   OR (route_name = 'Vereda Buenavista' AND activity_name = 'Parapente')
   OR (route_name = 'Vereda Buenavista' AND activity_name = 'Caminata ecológica')
   OR (route_name = 'Vereda Argentina' AND activity_name = 'Cascada 3 Colores');

-- 2. Insertar las nuevas imágenes
INSERT INTO activity_images (route_name, activity_name, image_url, display_order)
VALUES
  -- Vereda Buenavista / Miradores
  ('Vereda Buenavista', 'Miradores', 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/activity-images/vereda-buenavista/miradores/mirador-buenavista-img1-panoramica.jpeg', 1),
  ('Vereda Buenavista', 'Miradores', 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/activity-images/vereda-buenavista/miradores/mirador-buenavista-img2-panomarica.jpeg', 2),

  -- Vereda Buenavista / Parapente
  ('Vereda Buenavista', 'Parapente', 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/activity-images/vereda-buenavista/parapente/parapente-img1-panoramica.jpeg', 1),
  ('Vereda Buenavista', 'Parapente', 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/activity-images/vereda-buenavista/parapente/parapente-img2-panoramica.jpeg', 2),
  ('Vereda Buenavista', 'Parapente', 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/activity-images/vereda-buenavista/parapente/parapente-img3.jpeg', 3),

  -- Vereda Buenavista / Caminata ecológica
  ('Vereda Buenavista', 'Caminata ecológica', 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/activity-images/vereda-buenavista/img-buenavista-panoramica.jpeg', 1),

  -- Vereda Argentina / Cascada 3 Colores
  ('Vereda Argentina', 'Cascada 3 Colores', 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/activity-images/vereda-argentina/cascada-3-colores-img1.jpeg', 1),
  ('Vereda Argentina', 'Cascada 3 Colores', 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/activity-images/vereda-argentina/cascada-3-colores-img2-panoramica.jpeg', 2),
  ('Vereda Argentina', 'Cascada 3 Colores', 'https://mxkdkfihshfbsvazmftg.supabase.co/storage/v1/object/public/activity-images/vereda-argentina/cascada-3-colores-img3-panoramica.jpeg', 3)
ON CONFLICT (route_name, activity_name, image_url)
DO UPDATE SET display_order = EXCLUDED.display_order;
