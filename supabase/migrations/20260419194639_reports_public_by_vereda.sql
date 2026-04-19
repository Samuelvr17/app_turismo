/*
  Migración: Reportes públicos filtrables por vereda.

  1. Agregar columna vereda_name (text NULL) a reports
  2. FK reports.vereda_name → safe_routes(name) ON DELETE SET NULL
  3. Índice compuesto por (vereda_name, created_at DESC)
  4. Reemplazar políticas RLS de reports:
     - SELECT público (anon + authenticated)
     - INSERT / UPDATE / DELETE restringido al dueño (auth.uid() = user_id)
  5. No se modifican otras tablas.
*/

-- ============================================================
-- 1. AGREGAR COLUMNA vereda_name
-- ============================================================
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS vereda_name text NULL;

-- ============================================================
-- 2. FK reports.vereda_name → safe_routes(name) ON DELETE SET NULL
-- ============================================================
ALTER TABLE public.reports
  ADD CONSTRAINT reports_vereda_name_fkey
  FOREIGN KEY (vereda_name) REFERENCES public.safe_routes(name) ON DELETE SET NULL;

-- ============================================================
-- 3. ÍNDICE por vereda_name y created_at DESC
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_reports_vereda_created
  ON public.reports (vereda_name, created_at DESC);

-- ============================================================
-- 4. REEMPLAZAR POLÍTICAS RLS de reports
--    SELECT → público (anon + authenticated)
--    INSERT / UPDATE / DELETE → solo dueño (auth.uid() = user_id)
-- ============================================================

-- Eliminar políticas anteriores (nombres históricos + actuales)
DROP POLICY IF EXISTS "Permitir lectura de reportes"    ON reports;
DROP POLICY IF EXISTS "Permitir inserción de reportes"  ON reports;
DROP POLICY IF EXISTS "Permitir eliminación de reportes" ON reports;
DROP POLICY IF EXISTS "reports_select_owner"             ON reports;
DROP POLICY IF EXISTS "reports_insert_owner"             ON reports;
DROP POLICY IF EXISTS "reports_update_owner"             ON reports;
DROP POLICY IF EXISTS "reports_delete_owner"             ON reports;
DROP POLICY IF EXISTS "reports_select_public"            ON reports;

-- SELECT: público para anon y authenticated
CREATE POLICY "reports_select_public"
  ON reports FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: solo el dueño
CREATE POLICY "reports_insert_owner"
  ON reports FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: solo el dueño
CREATE POLICY "reports_update_owner"
  ON reports FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: solo el dueño
CREATE POLICY "reports_delete_owner"
  ON reports FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
