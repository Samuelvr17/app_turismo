# 📚 Guía de Administración - Datos de Rutas en Supabase

## 🚀 Paso 1: Ejecutar la Migración SQL (SOLO UNA VEZ)

### Opción A: Usando Supabase CLI (Recomendado)

```bash
# En la terminal, dentro de tu proyecto
cd c:\flutter_projects\app_turismo

# Aplicar la migración
supabase db push
```

### Opción B: Usando el Dashboard de Supabase

1. Ve a [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Selecciona tu proyecto
3. Ve a **SQL Editor** en el menú lateral
4. Crea una nueva query
5. Copia y pega el contenido de:
   ```
   supabase/migrations/20251129000000_add_route_locations_and_activity_images.sql
   ```
6. Click en **Run** (o presiona `Ctrl + Enter`)
7. Verifica que diga "Success"

### ✅ Verificar que funcionó

1. Ve a **Table Editor** en el dashboard
2. Deberías ver dos nuevas tablas:
   - `route_locations` (con 2 filas)
   - `activity_images` (con 13 filas)

---

## 📸 Paso 2: Subir Imágenes Locales a Supabase Storage

Actualmente tienes imágenes en `assets/images/` que necesitas subir a Supabase.

### Crear el Bucket

1. En el dashboard de Supabase, ve a **Storage**
2. Click en **New bucket**
3. Nombre: `activity-images`
4. **Importante:** Marca como **Public** ✅
5. Click en **Create bucket**

### Subir las Imágenes

**Imágenes a subir:**
- `assets/images/vereda-buenavista/parapente/bryan-goff-IuyhXAia8EA-unsplash.jpg`
- `assets/images/vereda-argentina/arg1.jpg`
- `assets/images/vereda-argentina/arg2.jpg`
- `assets/images/vereda-argentina/arg3.jpg`

**Proceso:**

1. Ve a **Storage** → `activity-images`
2. Crea carpetas para organizar:
   - Click en **New folder** → `vereda-buenavista`
   - Click en **New folder** → `vereda-argentina`

3. Sube las imágenes:
   - Entra a la carpeta `vereda-buenavista`
   - Click en **Upload file**
   - Selecciona `bryan-goff-IuyhXAia8EA-unsplash.jpg`
   - Repite para las otras imágenes en sus respectivas carpetas

4. Obtén las URLs públicas:
   - Click en cada imagen
   - Click en **Copy URL**
   - Guarda estas URLs

### Actualizar las URLs en la Base de Datos

```sql
-- En SQL Editor, actualiza las URLs de las imágenes locales

-- Para Parapente
UPDATE activity_images
SET image_url = 'https://[tu-proyecto].supabase.co/storage/v1/object/public/activity-images/vereda-buenavista/bryan-goff-IuyhXAia8EA-unsplash.jpg'
WHERE route_name = 'Vereda Buenavista' 
  AND activity_name = 'Parapente';

-- Para Vereda Argentina - Ciclismo
UPDATE activity_images
SET image_url = 'https://[tu-proyecto].supabase.co/storage/v1/object/public/activity-images/vereda-argentina/arg1.jpg'
WHERE route_name = 'Vereda Argentina' 
  AND activity_name = 'Ciclismo' 
  AND display_order = 1;

UPDATE activity_images
SET image_url = 'https://[tu-proyecto].supabase.co/storage/v1/object/public/activity-images/vereda-argentina/arg2.jpg'
WHERE route_name = 'Vereda Argentina' 
  AND activity_name = 'Ciclismo' 
  AND display_order = 2;

UPDATE activity_images
SET image_url = 'https://[tu-proyecto].supabase.co/storage/v1/object/public/activity-images/vereda-argentina/arg3.jpg'
WHERE route_name = 'Vereda Argentina' 
  AND activity_name = 'Ciclismo' 
  AND display_order = 3;

-- Repetir para Caminata (mismo proceso)
```

> **Nota:** Reemplaza `[tu-proyecto]` con el nombre real de tu proyecto de Supabase.

---

## ➕ Cómo Crear una Nueva Ruta

### 1. Agregar la Ubicación

```sql
INSERT INTO route_locations (route_name, latitude, longitude) 
VALUES ('Vereda El Paraíso', 4.123456, -73.654321);
```

### 2. Agregar Imágenes de Actividades

```sql
-- Ejemplo: Agregar actividad de Senderismo con 2 imágenes
INSERT INTO activity_images (route_name, activity_name, image_url, display_order) 
VALUES 
  ('Vereda El Paraíso', 'Senderismo', 'https://images.unsplash.com/photo-xxx', 1),
  ('Vereda El Paraíso', 'Senderismo', 'https://images.unsplash.com/photo-yyy', 2);
```

### 3. Actualizar la App

**No necesitas hacer nada más!** 🎉

La app cargará automáticamente los nuevos datos la próxima vez que:
- Se abra la app
- Se navegue a "Rutas Seguras"
- Pase 24 horas (caché expira)

---

## 🔄 Cómo Actualizar Datos Existentes

### Cambiar Ubicación de una Ruta

```sql
UPDATE route_locations
SET latitude = 4.999999, longitude = -73.888888
WHERE route_name = 'Vereda Buenavista';
```

### Agregar Más Imágenes a una Actividad

```sql
INSERT INTO activity_images (route_name, activity_name, image_url, display_order) 
VALUES ('Vereda Buenavista', 'Miradores', 'https://nueva-imagen.jpg', 3);
```

### Cambiar el Orden de las Imágenes

```sql
-- Cambiar imagen que está en posición 1 a posición 3
UPDATE activity_images
SET display_order = 3
WHERE route_name = 'Vereda Buenavista' 
  AND activity_name = 'Miradores'
  AND display_order = 1;
```

### Eliminar una Imagen

```sql
DELETE FROM activity_images
WHERE route_name = 'Vereda Buenavista' 
  AND activity_name = 'Parapente'
  AND image_url = 'https://imagen-a-eliminar.jpg';
```

---

## 🖼️ Cómo Subir Nuevas Imágenes

### Opción 1: Usar Unsplash (Más Fácil)

1. Ve a [https://unsplash.com](https://unsplash.com)
2. Busca la imagen que quieres
3. Click derecho en la imagen → "Copy image address"
4. Usa esa URL en la base de datos

**Ejemplo:**
```sql
INSERT INTO activity_images (route_name, activity_name, image_url, display_order) 
VALUES ('Vereda Buenavista', 'Miradores', 
        'https://images.unsplash.com/photo-1234567890?auto=format&fit=crop&w=1200&q=80', 
        3);
```

### Opción 2: Subir a Supabase Storage

1. Ve a **Storage** → `activity-images`
2. Navega a la carpeta correcta (o crea una nueva)
3. Click en **Upload file**
4. Selecciona tu imagen
5. Click en la imagen → **Copy URL**
6. Usa esa URL en la base de datos

---

## 🧪 Probar los Cambios

### En la App

```bash
# Ejecutar la app
flutter run
```

1. Navega a "Rutas Seguras"
2. Verifica que veas las rutas correctas
3. Click en una actividad
4. Verifica que las imágenes se carguen

### Forzar Recarga de Datos

Si hiciste cambios y no se reflejan:

```dart
// Opción 1: Reiniciar la app (más fácil)
// Cierra y abre la app de nuevo

// Opción 2: Limpiar caché (si necesitas)
// Agrega esto temporalmente en algún botón:
RouteDataService.instance.clearCache();
```

---

## 📊 Consultas Útiles

### Ver Todas las Rutas

```sql
SELECT * FROM route_locations ORDER BY route_name;
```

### Ver Todas las Imágenes de una Ruta

```sql
SELECT activity_name, image_url, display_order
FROM activity_images
WHERE route_name = 'Vereda Buenavista'
ORDER BY activity_name, display_order;
```

### Contar Imágenes por Actividad

```sql
SELECT route_name, activity_name, COUNT(*) as total_images
FROM activity_images
GROUP BY route_name, activity_name
ORDER BY route_name, activity_name;
```

---

## ⚠️ Solución de Problemas

### "No se pudieron cargar los datos de rutas"

**Causa:** Error de conexión a Supabase

**Solución:**
1. Verifica que tengas internet
2. Verifica que las tablas existan en Supabase
3. La app usará datos cacheados si están disponibles

### Las imágenes no se muestran

**Causa:** URL incorrecta o bucket no público

**Solución:**
1. Verifica que el bucket `activity-images` sea **Public**
2. Verifica que las URLs sean correctas
3. Prueba abrir la URL en el navegador

### Los cambios no se reflejan

**Causa:** Caché de 24 horas

**Solución:**
1. Espera 24 horas, o
2. Reinicia la app completamente, o
3. Llama a `RouteDataService.instance.clearCache()`

---

## 🎯 Resumen de Acciones Locales

**LO QUE DEBES HACER LOCALMENTE:**

1. ✅ **Ejecutar migración** (solo una vez):
   ```bash
   supabase db push
   ```

2. ✅ **Subir imágenes a Storage** (solo una vez):
   - Ir al dashboard de Supabase
   - Storage → activity-images
   - Subir las 4 imágenes locales

3. ✅ **Actualizar URLs en la BD** (solo una vez):
   - Copiar las URLs públicas de Storage
   - Ejecutar los UPDATE queries

4. ✅ **Probar la app**:
   ```bash
   flutter run
   ```

**NO NECESITAS:**
- ❌ Cambiar código adicional
- ❌ Instalar paquetes nuevos
- ❌ Configurar nada más en Flutter
- ❌ Recompilar para agregar nuevas rutas en el futuro

---

## 🎉 ¡Listo!

Ahora puedes administrar todas las rutas e imágenes desde Supabase sin tocar código. 

**Beneficios:**
- ✅ Agregar rutas sin recompilar
- ✅ Cambiar imágenes sin recompilar
- ✅ Funciona offline (usa caché)
- ✅ Actualización automática cada 24h
- ✅ Panel web para administrar
