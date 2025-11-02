-- Ajusta safe_routes para uso global y restringe escrituras desde el cliente

-- Eliminar índice compuesto basado en user_id y nombre
DROP INDEX IF EXISTS safe_routes_user_id_name_key;

-- Quitar la columna user_id; las rutas ahora son compartidas globalmente
ALTER TABLE safe_routes
  DROP COLUMN IF EXISTS user_id;

-- Asegurar que name siga siendo único. Si el constraint ya existe, no se duplica.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.safe_routes'::regclass
      AND conname = 'safe_routes_name_key'
  ) THEN
    ALTER TABLE safe_routes
      ADD CONSTRAINT safe_routes_name_key UNIQUE (name);
  END IF;
END
$$;

-- Reemplazar políticas para que solo permitan lectura pública
DROP POLICY IF EXISTS "Permitir lectura de rutas seguras" ON safe_routes;
DROP POLICY IF EXISTS "Permitir inserción de rutas seguras" ON safe_routes;
DROP POLICY IF EXISTS "Permitir actualización de rutas seguras" ON safe_routes;

CREATE POLICY "safe_routes_select_public"
  ON safe_routes
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Cargar rutas seguras predeterminadas disponibles para todos los usuarios
INSERT INTO safe_routes (name, duration, difficulty, description, points_of_interest)
VALUES
  (
    'Vereda Buenavista',
    'A 15 minutos de Villavicencio',
    'Actividades para todos',
    '🍃 La vereda Buenavista ofrece un clima distinto en Villavicencio, a tan solo 15 minutos de su casco urbano, ideal para el turismo deportivo, de naturaleza y religioso.',
    ARRAY['Miradores', 'Parapente', 'Caminata ecológica']::text[]
  ),
  (
    'Vereda Argentina',
    'A 20 minutos de Villavicencio',
    'Naturaleza y aventura',
    '🚴‍♀️ La vereda Argentina combina montañas, paisajes llaneros y caminos ideales para disfrutar de actividades al aire libre con toda la familia.',
    ARRAY['Ciclismo', 'Caminata']::text[]
  )
ON CONFLICT (name) DO UPDATE
SET
  duration = EXCLUDED.duration,
  difficulty = EXCLUDED.difficulty,
  description = EXCLUDED.description,
  points_of_interest = EXCLUDED.points_of_interest,
  updated_at = now();
