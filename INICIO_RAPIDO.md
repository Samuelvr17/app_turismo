# Inicio Rápido - Configuración de Supabase

## Resumen de pasos

### 1. Crear proyecto en Supabase
- Ve a [https://supabase.com](https://supabase.com) y crea una cuenta
- Crea un nuevo proyecto

### 2. Obtener credenciales
- Ve a **Settings > API**
- Copia el **Project URL** y **anon public key**

### 3. Configurar archivo .env
Edita el archivo `.env` en la raíz del proyecto:

```
SUPABASE_URL=tu-url-aqui
SUPABASE_ANON_KEY=tu-key-aqui
```

### 4. Ejecutar migración SQL
- En Supabase, ve a **SQL Editor**
- Ejecuta el contenido de `supabase/migrations/20250101000000_initial_schema.sql`

### 5. Instalar dependencias y ejecutar

```bash
flutter pub get
flutter run
```

## ¿Necesitas más detalles?

Consulta el archivo [CONFIGURACION_SUPABASE.md](./CONFIGURACION_SUPABASE.md) para una guía completa paso a paso.

## Arquitectura del proyecto

El proyecto ahora usa un sistema híbrido de almacenamiento:

1. **Almacenamiento local** (Hive + SharedPreferences): Para respaldo y funcionamiento offline
2. **Almacenamiento en Supabase**: Para sincronización en la nube

Cuando guardas datos:
1. Se intenta guardar en Supabase primero
2. Se guarda localmente como respaldo
3. Si Supabase falla, solo se guarda localmente

## Servicios disponibles

### SupabaseService
- Maneja toda la comunicación con Supabase
- Ubicación: `lib/services/supabase_service.dart`

### StorageService (recomendado)
- Servicio híbrido que combina local + Supabase
- Ubicación: `lib/services/storage_service.dart`
- Usa este servicio para operaciones de datos

### LocalStorageService
- Almacenamiento local puro (Hive + SharedPreferences)
- Ubicación: `lib/services/local_storage_service.dart`

## Estructura de la base de datos

### Tabla: reports
- `id`: ID único del reporte
- `type_id`: Tipo de reporte (security, infrastructure, service, other)
- `description`: Descripción del reporte
- `latitude`: Coordenada de latitud (opcional)
- `longitude`: Coordenada de longitud (opcional)
- `created_at`: Fecha de creación

### Tabla: safe_routes
- `id`: ID único de la ruta
- `name`: Nombre de la ruta
- `duration`: Duración estimada
- `difficulty`: Nivel de dificultad
- `description`: Descripción
- `points_of_interest`: Array de puntos de interés
- `created_at`, `updated_at`: Fechas de creación y actualización

### Tabla: user_preferences
- `id`: ID único
- `preferred_report_type_id`: Tipo de reporte preferido
- `share_location`: Si compartir ubicación por defecto
- `created_at`, `updated_at`: Fechas de creación y actualización

## Modificar el código existente (opcional)

Si quieres usar directamente Supabase en lugar del sistema híbrido, puedes reemplazar las referencias a `LocalStorageService` por `StorageService` o `SupabaseService` en tu código.

Ejemplo en `lib/main.dart`:

```dart
// En lugar de:
final LocalStorageService _storageService = LocalStorageService.instance;

// Usa:
final StorageService _storageService = StorageService.instance;
```

## Ventajas del sistema actual

✅ Funciona offline (guarda localmente)
✅ Sincroniza con la nube cuando hay internet
✅ Respaldo automático en ambos lugares
✅ Fácil de migrar a 100% Supabase más adelante

## Notas de seguridad

Las tablas actuales tienen acceso público. Para producción, considera:

1. Implementar autenticación de usuarios
2. Configurar políticas RLS más restrictivas
3. Validar datos del lado del servidor
