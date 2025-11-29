/*
  # Migración: Datos de Rutas y Actividades
  
  Crea tablas para almacenar ubicaciones de rutas e imágenes de actividades
  que actualmente están hardcoded en rutas_seguras_page.dart
  
  ## Nuevas Tablas
  
  1. `route_locations` - Ubicaciones GPS de las rutas
  2. `activity_images` - Imágenes asociadas a actividades de cada ruta
  
  ## Storage
  
  - Bucket: `activity-images` (público) para imágenes locales
*/

-- Crear tabla de ubicaciones de rutas
CREATE TABLE IF NOT EXISTS route_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  route_name text NOT NULL UNIQUE,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Crear tabla de imágenes de actividades
CREATE TABLE IF NOT EXISTS activity_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  route_name text NOT NULL,
  activity_name text NOT NULL,
  image_url text NOT NULL,
  display_order int DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  
  -- Constraint para evitar duplicados
  UNIQUE(route_name, activity_name, image_url)
);

-- Habilitar RLS
ALTER TABLE route_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_images ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad para route_locations (lectura pública, escritura autenticada)
CREATE POLICY "Permitir lectura pública de ubicaciones"
  ON route_locations
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Permitir inserción autenticada de ubicaciones"
  ON route_locations
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Permitir actualización autenticada de ubicaciones"
  ON route_locations
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Políticas de seguridad para activity_images (lectura pública, escritura autenticada)
CREATE POLICY "Permitir lectura pública de imágenes"
  ON activity_images
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Permitir inserción autenticada de imágenes"
  ON activity_images
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Permitir actualización autenticada de imágenes"
  ON activity_images
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Permitir eliminación autenticada de imágenes"
  ON activity_images
  FOR DELETE
  TO authenticated
  USING (true);

-- Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_route_locations_route_name ON route_locations(route_name);
CREATE INDEX IF NOT EXISTS idx_activity_images_route_name ON activity_images(route_name);
CREATE INDEX IF NOT EXISTS idx_activity_images_activity_name ON activity_images(activity_name);
CREATE INDEX IF NOT EXISTS idx_activity_images_display_order ON activity_images(route_name, activity_name, display_order);

-- Insertar datos actuales de rutas_seguras_page.dart
INSERT INTO route_locations (route_name, latitude, longitude) VALUES
  ('Vereda Buenavista', 4.157296670026874, -73.68158509824853),
  ('Vereda Argentina', 4.201476, -73.638586)
ON CONFLICT (route_name) DO NOTHING;

-- Insertar imágenes de actividades (manteniendo URLs de Unsplash)
INSERT INTO activity_images (route_name, activity_name, image_url, display_order) VALUES
  -- Vereda Buenavista - Miradores
  ('Vereda Buenavista', 'Miradores', 'https://images.unsplash.com/photo-1491557345352-5929e343eb89?auto=format&fit=crop&w=1200&q=80', 1),
  ('Vereda Buenavista', 'Miradores', 'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?auto=format&fit=crop&w=1200&q=80', 2),
  
  -- Vereda Buenavista - Parapente
  ('Vereda Buenavista', 'Parapente', 'assets/images/vereda-buenavista/parapente/bryan-goff-IuyhXAia8EA-unsplash.jpg', 1),
  
  -- Vereda Buenavista - Caminata ecológica
  ('Vereda Buenavista', 'Caminata ecológica', 'https://images.unsplash.com/photo-1470246973918-29a93221c455?auto=format&fit=crop&w=1200&q=80', 1),
  ('Vereda Buenavista', 'Caminata ecológica', 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1200&q=80', 2),
  
  -- Vereda Argentina - Ciclismo
  ('Vereda Argentina', 'Ciclismo', 'assets/images/vereda-argentina/arg1.jpg', 1),
  ('Vereda Argentina', 'Ciclismo', 'assets/images/vereda-argentina/arg2.jpg', 2),
  ('Vereda Argentina', 'Ciclismo', 'assets/images/vereda-argentina/arg3.jpg', 3),
  
  -- Vereda Argentina - Caminata
  ('Vereda Argentina', 'Caminata', 'assets/images/vereda-argentina/arg1.jpg', 1),
  ('Vereda Argentina', 'Caminata', 'assets/images/vereda-argentina/arg2.jpg', 2),
  ('Vereda Argentina', 'Caminata', 'assets/images/vereda-argentina/arg3.jpg', 3)
ON CONFLICT (route_name, activity_name, image_url) DO NOTHING;

-- Crear bucket de storage para imágenes (si no existe)
-- NOTA: Esto debe ejecutarse en el dashboard de Supabase Storage
-- Nombre del bucket: activity-images
-- Configuración: Público
