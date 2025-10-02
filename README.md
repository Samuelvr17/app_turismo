# App Turismo

Una aplicación Flutter para turismo seguro con integración de Supabase.

## Características

- Mapa interactivo con zonas de peligro
- Rutas seguras para turistas
- Sistema de reportes con geolocalización
- Información del clima en tiempo real
- Almacenamiento híbrido (local + nube)

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

5. Ejecuta la migración SQL (ver instrucciones completas)
6. Instala dependencias: `flutter pub get`
7. Ejecuta la app: `flutter run`

### Documentación completa

Para instrucciones detalladas paso a paso, consulta:

- [INICIO_RAPIDO.md](./INICIO_RAPIDO.md) - Guía rápida
- [CONFIGURACION_SUPABASE.md](./CONFIGURACION_SUPABASE.md) - Guía completa con capturas y solución de problemas

## Requisitos

- Flutter SDK 3.9.0 o superior
- Dart 3.9.0 o superior
- Una cuenta de Supabase (gratuita)
- Android SDK / Xcode (para desarrollo móvil)

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

## Estructura del proyecto

```
lib/
├── main.dart                 # Punto de entrada de la aplicación
├── models/                   # Modelos de datos
│   ├── report.dart
│   ├── safe_route.dart
│   ├── user_preferences.dart
│   └── weather_data.dart
├── services/                 # Servicios de la aplicación
│   ├── supabase_service.dart      # Cliente de Supabase
│   ├── storage_service.dart       # Servicio híbrido (recomendado)
│   ├── local_storage_service.dart # Almacenamiento local
│   ├── location_service.dart
│   └── weather_service.dart
└── widgets/                  # Widgets reutilizables
    └── weather_card.dart
```

## Arquitectura de datos

La aplicación utiliza un sistema híbrido de almacenamiento:

- **Almacenamiento local**: Hive + SharedPreferences (para funcionamiento offline)
- **Almacenamiento en nube**: Supabase (para sincronización entre dispositivos)

Los datos se guardan primero en Supabase y luego localmente como respaldo. Si Supabase no está disponible, los datos se guardan solo localmente.

## Base de datos

### Tablas en Supabase

- `reports`: Reportes de usuarios con geolocalización
- `safe_routes`: Rutas turísticas seguras
- `user_preferences`: Preferencias del usuario

Ver el archivo `supabase/migrations/20250101000000_initial_schema.sql` para el schema completo.

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
```

No subas este archivo a control de versiones.

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
