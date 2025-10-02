/*
  # Schema inicial para App Turismo

  1. Nuevas Tablas
    - `reports`
      - `id` (bigint, primary key, auto-increment)
      - `type_id` (text, tipo de reporte)
      - `description` (text, descripción del reporte)
      - `latitude` (double precision, coordenada de latitud opcional)
      - `longitude` (double precision, coordenada de longitud opcional)
      - `created_at` (timestamptz, fecha de creación)

    - `safe_routes`
      - `id` (bigint, primary key, auto-increment)
      - `name` (text, nombre de la ruta)
      - `duration` (text, duración estimada)
      - `difficulty` (text, nivel de dificultad)
      - `description` (text, descripción de la ruta)
      - `points_of_interest` (text array, puntos de interés)
      - `created_at` (timestamptz, fecha de creación)
      - `updated_at` (timestamptz, fecha de actualización)

    - `user_preferences`
      - `id` (bigint, primary key, auto-increment)
      - `preferred_report_type_id` (text, tipo de reporte preferido)
      - `share_location` (boolean, compartir ubicación por defecto)
      - `created_at` (timestamptz, fecha de creación)
      - `updated_at` (timestamptz, fecha de actualización)

  2. Seguridad
    - Habilitar RLS en todas las tablas
    - Permitir acceso público para lectura y escritura (puedes modificar esto según tus necesidades)
*/

-- Crear tabla de reportes
CREATE TABLE IF NOT EXISTS reports (
  id bigserial PRIMARY KEY,
  type_id text NOT NULL,
  description text NOT NULL,
  latitude double precision,
  longitude double precision,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Crear tabla de rutas seguras
CREATE TABLE IF NOT EXISTS safe_routes (
  id bigserial PRIMARY KEY,
  name text NOT NULL UNIQUE,
  duration text NOT NULL,
  difficulty text NOT NULL,
  description text NOT NULL,
  points_of_interest text[] DEFAULT '{}' NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Crear tabla de preferencias de usuario
CREATE TABLE IF NOT EXISTS user_preferences (
  id bigserial PRIMARY KEY,
  preferred_report_type_id text,
  share_location boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Habilitar RLS
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE safe_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad para reports (acceso público)
CREATE POLICY "Permitir lectura de reportes"
  ON reports
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Permitir inserción de reportes"
  ON reports
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Permitir eliminación de reportes"
  ON reports
  FOR DELETE
  TO anon, authenticated
  USING (true);

-- Políticas de seguridad para safe_routes (acceso público)
CREATE POLICY "Permitir lectura de rutas seguras"
  ON safe_routes
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Permitir inserción de rutas seguras"
  ON safe_routes
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Permitir actualización de rutas seguras"
  ON safe_routes
  FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Políticas de seguridad para user_preferences (acceso público)
CREATE POLICY "Permitir lectura de preferencias"
  ON user_preferences
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Permitir inserción de preferencias"
  ON user_preferences
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Permitir actualización de preferencias"
  ON user_preferences
  FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_type_id ON reports(type_id);
CREATE INDEX IF NOT EXISTS idx_safe_routes_name ON safe_routes(name);
