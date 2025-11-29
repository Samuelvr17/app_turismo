# App Turismo

Una aplicación Flutter para turismo seguro con integración de Supabase.

## Características

- **Mapa interactivo** con zonas de peligro en tiempo real
- **Location-Based AR** para visualizar zonas de peligro con la cámara
- **Rutas seguras** para turistas con gestión dinámica desde Supabase
- **Sistema de reportes** con geolocalización
- **Recomendaciones personalizadas** de actividades basadas en IA
- **Información del clima** en tiempo real para actividades específicas
- **Almacenamiento híbrido** (local + nube) con soporte offline
- **Gestión dinámica de contenido** sin necesidad de recompilar la app

## Configuración de Supabase

Esta aplicación usa Supabase como backend. Antes de ejecutar la aplicación, necesitas configurar tu proyecto de Supabase.

### Inicio Rápido

1. Crea una cuenta en [Supabase](https://supabase.com)
2. Crea un nuevo proyecto
3. Copia tus credenciales (URL y anon key)
4. Configura el archivo `.env`:

```
SUPABASE_URL=tu-url-aqui
SUPABASE_ANON_KEY=tu-key-aqui
```

5. Ejecuta las migraciones SQL:

```bash
supabase db push
```

6. Configura el bucket de imágenes (ver guía de administración)
7. Instala dependencias: `flutter pub get`
8. Ejecuta la app: `flutter run`

### Documentación completa

Para instrucciones detalladas paso a paso, consulta:

- [INICIO_RAPIDO.md](./INICIO_RAPIDO.md) - Guía rápida de configuración
- [CONFIGURACION_SUPABASE.md](./CONFIGURACION_SUPABASE.md) - Guía completa con capturas y solución de problemas
- [docs/SUPABASE_ADMIN_GUIDE.md](./docs/SUPABASE_ADMIN_GUIDE.md) - Administración de rutas y contenido dinámico
- [docs/MIGRATION_COMPLETE.md](./docs/MIGRATION_COMPLETE.md) - Detalles de la migración de datos

## Requisitos

- Flutter SDK 3.9.0 o superior
- Dart 3.9.0 o superior
- Una cuenta de Supabase (gratuita)
- Android SDK / Xcode (para desarrollo móvil)
- Dispositivo físico con ARCore (Android) o ARKit (iOS) para funcionalidad AR

## Instalación

1. Clona el repositorio
2. Instala las dependencias:

```bash
flutter pub get
```

3. Configura Supabase (ver sección anterior)
4. Ejecuta la aplicación:

```bash
flutter run
```

### Probar la vista de zonas de peligro en AR

1. Asegúrate de tener un dispositivo físico compatible con ARCore (Android) o ARKit (iOS); la vista de realidad aumentada necesita cámara y sensores, por lo que no funcionará en emuladores/simuladores.
2. Instala las dependencias:

   ```bash
   flutter pub get
   ```

3. En iOS, instala los pods antes de ejecutar el proyecto:

   ```bash
   cd ios && pod install && cd ..
   ```

4. Ejecuta la app como de costumbre, incluyendo tu clave de OpenWeather si la usas para el clima:

   ```bash
   flutter run --dart-define=OPENWEATHER_API_KEY=TU_API_KEY
   ```

5. Otorga los permisos de ubicación y cámara cuando la app los solicite (son necesarios para la vista AR).
6. Desde la pantalla del mapa, usa el botón flotante **"Ver en AR"** para abrir la superposición de zonas de peligro en realidad aumentada, que utilizará tu posición actual para resaltar las zonas activas.

## Estructura del proyecto

```
lib/
├── main.dart                 # Punto de entrada de la aplicación
├── data/                     # Datos estáticos y configuración
│   └── default_safe_routes.dart
├── models/                   # Modelos de datos
│   ├── activity_recommendation.dart
│   ├── activity_survey.dart
│   ├── danger_zone.dart
│   ├── danger_zone_point.dart
│   ├── report.dart
│   ├── safe_route.dart
│   ├── user_preferences.dart
│   └── weather_data.dart
├── pages/                    # Páginas principales de la aplicación
│   ├── activity_survey_page.dart
│   ├── login_page.dart
│   ├── mapa_page.dart
│   ├── profile_page.dart
│   ├── recommendations_page.dart
│   ├── reportes_page.dart
│   └── rutas_seguras_page.dart
├── services/                 # Servicios de la aplicación
│   ├── activity_survey_service.dart
│   ├── ar_calculation_service.dart
│   ├── auth_service.dart
│   ├── local_storage_service.dart
│   ├── location_service.dart
│   ├── recommendation_api_service.dart
│   ├── reports_remote_data_source.dart
│   ├── route_data_service.dart      # ⭐ Gestión dinámica de rutas
│   ├── safe_route_local_data_source.dart
│   ├── storage_service.dart
│   ├── supabase_service.dart
│   ├── weather_service.dart
│   └── zone_detection_service.dart
└── widgets/                  # Widgets reutilizables
    ├── ar_camera_view.dart
    ├── ar_danger_zone_view.dart
    ├── danger_zone_alert_dialog.dart
    └── weather_card.dart

supabase/
└── migrations/               # Migraciones de base de datos
    ├── 20250101000000_initial_schema.sql
    ├── 20251129000000_add_route_locations_and_activity_images.sql
    └── ...

docs/                         # Documentación adicional
├── SUPABASE_ADMIN_GUIDE.md  # Guía de administración de contenido
└── MIGRATION_COMPLETE.md    # Detalles de migración de datos
```

## Arquitectura de datos

La aplicación utiliza un sistema híbrido de almacenamiento:

- **Almacenamiento local**: Hive + SharedPreferences (para funcionamiento offline)
- **Almacenamiento en nube**: Supabase (para sincronización entre dispositivos)
- **Caché inteligente**: Los datos de rutas se cachean por 24 horas para mejor rendimiento

Los datos se guardan primero en Supabase y luego localmente como respaldo. Si Supabase no está disponible, los datos se guardan solo localmente.

## Base de datos

### Tablas en Supabase

- `reports`: Reportes de usuarios con geolocalización
- `safe_routes`: Rutas turísticas seguras
- `user_preferences`: Preferencias del usuario
- `danger_zones`: Zonas de peligro con información detallada
- `danger_zone_points`: Puntos específicos dentro de zonas de peligro
- `route_locations`: Ubicaciones GPS de rutas (gestión dinámica)
- `activity_images`: Imágenes de actividades por ruta (gestión dinámica)

### Storage Buckets

- `activity-images`: Imágenes de actividades turísticas (público)

Ver el directorio `supabase/migrations/` para el schema completo.

## Configuración adicional

### API de Google Maps

Para que el mapa funcione correctamente, necesitas configurar tu API key de Google Maps:

**Android**: Edita `android/app/src/main/AndroidManifest.xml`

**iOS**: Edita `ios/Runner/AppDelegate.swift`

### Variables de entorno

El archivo `.env` debe contener:

```
SUPABASE_URL=tu-url-de-supabase
SUPABASE_ANON_KEY=tu-anon-key-de-supabase
RECOMMENDATION_API_URL=http://127.0.0.1:8000
```

No subas este archivo a control de versiones.

### Servicio de recomendaciones basado en IA

El repositorio incluye una API independiente construida con FastAPI en la carpeta `ai_service/`. Debes ejecutarla aparte de la
aplicación Flutter. La app móvil envía al servicio las actividades disponibles (los puntos de interés de las rutas seguras)
para que las recomendaciones se limiten a lo que realmente existe en la base de datos.

1. Crea y activa un entorno virtual de Python (opcional pero recomendado).
2. Instala las dependencias:

   ```bash
   pip install -r ai_service/requirements.txt
   ```

3. Ejecuta el servidor:

   ```bash
   uvicorn ai_service.app.main:app --reload --host 0.0.0.0 --port 8000
   ```

4. Ajusta `RECOMMENDATION_API_URL` en tu `.env` si utilizas otro host o puerto.

## Desarrollo

### Ejecutar en modo debug

```bash
flutter run
```

### Ejecutar tests

```bash
flutter test
```

### Generar build

```bash
# Android
flutter build apk

# iOS
flutter build ios
```

## Solución de problemas

Si encuentras problemas durante la configuración, consulta la sección de "Solución de problemas comunes" en [CONFIGURACION_SUPABASE.md](./CONFIGURACION_SUPABASE.md).

## Recursos

- [Documentación de Flutter](https://docs.flutter.dev/)
- [Documentación de Supabase](https://supabase.com/docs)
- [Plugin supabase_flutter](https://pub.dev/packages/supabase_flutter)

## Licencia

Este proyecto es un proyecto de ejemplo para propósitos educativos.
