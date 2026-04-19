/*
  Migración: Corregir FK de user_id hacia auth.users y restringir RLS por dueño.

  1. Truncar tablas de datos de usuario
  2. Eliminar tabla app_users
  3. Recrear FK de user_id → auth.users(id) ON DELETE CASCADE
  4. Reemplazar políticas RLS para acceso solo del dueño (auth.uid() = user_id)
  5. NO se modifican: safe_routes, danger_zones, danger_zone_points,
     route_locations, activity_images
*/

-- ============================================================
-- 1. TRUNCAR TABLAS DE DATOS DE USUARIO
-- ============================================================
TRUNCATE TABLE
  activity_recommendations,
  user_activity_surveys,
  user_preferences,
  reports
CASCADE;

-- ============================================================
-- 2. ELIMINAR TABLA app_users
-- ============================================================
DROP TABLE IF EXISTS app_users CASCADE;

-- ============================================================
-- 3. RECREAR FK DE user_id → auth.users(id) ON DELETE CASCADE
--    Usamos un bloque DO $$ para buscar y eliminar cualquier FK
--    existente sobre user_id sin importar el nombre exacto.
-- ============================================================

-- --- reports ---
DO $$
DECLARE
  _con text;
BEGIN
  FOR _con IN
    SELECT constraint_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        USING (constraint_catalog, constraint_schema, constraint_name)
     WHERE tc.table_schema = 'public'
       AND tc.table_name   = 'reports'
       AND tc.constraint_type = 'FOREIGN KEY'
       AND kcu.column_name = 'user_id'
  LOOP
    EXECUTE format('ALTER TABLE public.reports DROP CONSTRAINT %I', _con);
  END LOOP;
END
$$;

ALTER TABLE public.reports
  ADD CONSTRAINT reports_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- --- user_preferences ---
DO $$
DECLARE
  _con text;
BEGIN
  FOR _con IN
    SELECT constraint_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        USING (constraint_catalog, constraint_schema, constraint_name)
     WHERE tc.table_schema = 'public'
       AND tc.table_name   = 'user_preferences'
       AND tc.constraint_type = 'FOREIGN KEY'
       AND kcu.column_name = 'user_id'
  LOOP
    EXECUTE format('ALTER TABLE public.user_preferences DROP CONSTRAINT %I', _con);
  END LOOP;
END
$$;

ALTER TABLE public.user_preferences
  ADD CONSTRAINT user_preferences_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- --- user_activity_surveys ---
DO $$
DECLARE
  _con text;
BEGIN
  FOR _con IN
    SELECT constraint_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        USING (constraint_catalog, constraint_schema, constraint_name)
     WHERE tc.table_schema = 'public'
       AND tc.table_name   = 'user_activity_surveys'
       AND tc.constraint_type = 'FOREIGN KEY'
       AND kcu.column_name = 'user_id'
  LOOP
    EXECUTE format('ALTER TABLE public.user_activity_surveys DROP CONSTRAINT %I', _con);
  END LOOP;
END
$$;

ALTER TABLE public.user_activity_surveys
  ADD CONSTRAINT user_activity_surveys_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- --- activity_recommendations ---
DO $$
DECLARE
  _con text;
BEGIN
  FOR _con IN
    SELECT constraint_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        USING (constraint_catalog, constraint_schema, constraint_name)
     WHERE tc.table_schema = 'public'
       AND tc.table_name   = 'activity_recommendations'
       AND tc.constraint_type = 'FOREIGN KEY'
       AND kcu.column_name = 'user_id'
  LOOP
    EXECUTE format('ALTER TABLE public.activity_recommendations DROP CONSTRAINT %I', _con);
  END LOOP;
END
$$;

ALTER TABLE public.activity_recommendations
  ADD CONSTRAINT activity_recommendations_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ============================================================
-- 4. REEMPLAZAR POLÍTICAS RLS — solo el dueño (auth.uid() = user_id)
-- ============================================================

-- -----------------------------------------------
-- reports
-- -----------------------------------------------
DROP POLICY IF EXISTS "Permitir lectura de reportes"    ON reports;
DROP POLICY IF EXISTS "Permitir inserción de reportes"  ON reports;
DROP POLICY IF EXISTS "Permitir eliminación de reportes" ON reports;
DROP POLICY IF EXISTS "reports_select_owner"             ON reports;
DROP POLICY IF EXISTS "reports_insert_owner"             ON reports;
DROP POLICY IF EXISTS "reports_update_owner"             ON reports;
DROP POLICY IF EXISTS "reports_delete_owner"             ON reports;

CREATE POLICY "reports_select_owner"
  ON reports FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "reports_insert_owner"
  ON reports FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reports_update_owner"
  ON reports FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reports_delete_owner"
  ON reports FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- -----------------------------------------------
-- user_preferences
-- -----------------------------------------------
DROP POLICY IF EXISTS "Permitir lectura de preferencias"      ON user_preferences;
DROP POLICY IF EXISTS "Permitir inserción de preferencias"    ON user_preferences;
DROP POLICY IF EXISTS "Permitir actualización de preferencias" ON user_preferences;
DROP POLICY IF EXISTS "user_preferences_select_owner"          ON user_preferences;
DROP POLICY IF EXISTS "user_preferences_insert_owner"          ON user_preferences;
DROP POLICY IF EXISTS "user_preferences_update_owner"          ON user_preferences;
DROP POLICY IF EXISTS "user_preferences_delete_owner"          ON user_preferences;

CREATE POLICY "user_preferences_select_owner"
  ON user_preferences FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_preferences_insert_owner"
  ON user_preferences FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_preferences_update_owner"
  ON user_preferences FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_preferences_delete_owner"
  ON user_preferences FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- -----------------------------------------------
-- user_activity_surveys
-- -----------------------------------------------
DROP POLICY IF EXISTS "public_select_user_activity_surveys" ON user_activity_surveys;
DROP POLICY IF EXISTS "public_upsert_user_activity_surveys" ON user_activity_surveys;
DROP POLICY IF EXISTS "public_update_user_activity_surveys" ON user_activity_surveys;
DROP POLICY IF EXISTS "user_activity_surveys_select_owner"   ON user_activity_surveys;
DROP POLICY IF EXISTS "user_activity_surveys_insert_owner"   ON user_activity_surveys;
DROP POLICY IF EXISTS "user_activity_surveys_update_owner"   ON user_activity_surveys;
DROP POLICY IF EXISTS "user_activity_surveys_delete_owner"   ON user_activity_surveys;

CREATE POLICY "user_activity_surveys_select_owner"
  ON user_activity_surveys FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_activity_surveys_insert_owner"
  ON user_activity_surveys FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_activity_surveys_update_owner"
  ON user_activity_surveys FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_activity_surveys_delete_owner"
  ON user_activity_surveys FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- -----------------------------------------------
-- activity_recommendations
-- -----------------------------------------------
DROP POLICY IF EXISTS "public_select_activity_recommendations" ON activity_recommendations;
DROP POLICY IF EXISTS "public_insert_activity_recommendations" ON activity_recommendations;
DROP POLICY IF EXISTS "public_delete_activity_recommendations" ON activity_recommendations;
DROP POLICY IF EXISTS "activity_recommendations_select_owner"   ON activity_recommendations;
DROP POLICY IF EXISTS "activity_recommendations_insert_owner"   ON activity_recommendations;
DROP POLICY IF EXISTS "activity_recommendations_update_owner"   ON activity_recommendations;
DROP POLICY IF EXISTS "activity_recommendations_delete_owner"   ON activity_recommendations;

CREATE POLICY "activity_recommendations_select_owner"
  ON activity_recommendations FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "activity_recommendations_insert_owner"
  ON activity_recommendations FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "activity_recommendations_update_owner"
  ON activity_recommendations FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "activity_recommendations_delete_owner"
  ON activity_recommendations FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
