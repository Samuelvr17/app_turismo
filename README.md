# App Turismo

Una aplicación Flutter robusta para turismo seguro e inteligente, respaldada por integración con Supabase.

## ✨ Características Principales

- **Mapa interactivo** con zonas de peligro en tiempo real
- **Location-Based AR (Realidad Aumentada)** para visualizar advertencias proyectadas en el entorno con la cámara frontal
- **Visor Automático PDF (Offline)** con almacenamiento en caché local robusto para leer guías turísticas sin internet
- **Navegación Panorámica 360°** inmersiva de puntos de interés turístico
- **Rutas seguras** estructuradas y dinámicas obtenidas remoto desde Supabase
- **Sistema de Reportes Inclusivos** geolocalizados y filtrables por Vereda para uso de toda la comunidad
- **Recomendaciones Inteligentes** de recorridos generadas vía IA
- **Información Meteorológica en vivo** para prevención
- **Arquitectura de Resiliencia Híbrida** (funcionamiento con datos en la nube y respaldo local tipo caché)

## 🔧 Configuración Rápida de Supabase

Esta aplicación usa Supabase como backend. Antes de ejecutarla, debes configurar tu entorno:

1. Crea una cuenta y un proyecto en [Supabase](https://supabase.com)
2. Copia tus credenciales (Project URL y anon key) localizadas en tu dashboard de la API.
3. Crea un archivo `.env` en la raíz de tu proyecto e incrústa estas variables:

```env
SUPABASE_URL=tu-url-aqui
SUPABASE_ANON_KEY=tu-key-aqui
RECOMMENDATION_API_URL=http://127.0.0.1:8000
```

4. Ejecuta las migraciones pertinentes de la base de datos a tu proyecto en la nube:
```bash
supabase db push
```

5. Instala las dependencias y ejecuta la app:
```bash
flutter pub get
flutter run
```

## 📱 Requisitos e Instalación

- **Flutter SDK** 3.9.0 o superior (con Dart ^3.9.0)
- Una cuenta gratuita de Supabase
- Importante: Dispositivo móvil físico (ARCore en Android / ARKit en iOS) para probar las vistas LBAR de seguridad ya que no operarán en simuladores puros.

### Inicialización

1. Clona o abre el repositorio.
2. Instala dependencias:
   ```bash
   flutter pub get
   ```
3. (Solo para plataformas de iOS) instala las dependencias nativas:
   ```bash
   cd ios && pod install && cd ..
   ```
4. Pruébalo en vivo con soporte a la API del clima de OpenWeather (reemplazando tu llave):
   ```bash
   flutter run --dart-define=OPENWEATHER_API_KEY=TU_API_KEY
   ```
   *(Importante: Otorga los permisos en pantalla (Ubicación, Cámara) para habilitar el motor AR).*
5. Selecciona el botón para **Ver en AR** desde el mapa global. El teléfono interpretará vía sensores las ubicaciones y distancias. 

## 🗺 Arquitectura de Almacenamiento

El esquema de la arquitectura ha migrado para servir un diseño en la nube (Postgres + Storage) con respaldos estructurados locales por si la conectividad del dispositivo falla:

- `reports`: Listados comunitarios en vivo, filtrables por sus Veredas.
- `safe_routes` / `route_locations`: Catálogo turístico con posicionamiento geográfico dinámico.
- `activity_images` & Buckets públicos: Administración remota sin requerir futuras actualizaciones a la app en las tiendas.
- `user_preferences`: Configuraciones cross-session amparadas en IDs.
- `danger_zones` y dependientes `points`: Variables geo-fencing trazadas directamente contra la cámara.

## 🤖 Inicializar la API de Sugerencias vía IA Local

El motor de descubrimiento y sugerencias de Machine Learning (construido en Python con FastAPI) convive dentro del repositorio (en `ai_service/`) y necesita correr aparte.

1. Navega o crea tu entorno vitual en esa ruta y usa `pip`:
   ```bash
   pip install -r ai_service/requirements.txt
   uvicorn ai_service.app.main:app --reload --host 0.0.0.0 --port 8000
   ```
2. Asegúrate que `RECOMMENDATION_API_URL` en tu `.env` corresponda hacia el endpoint expuesto.

## ⚙ Compilación Continua

- Para levantar el visor en Hot Reload durante debbuging: `flutter run`
- Generar release pura (.apk) para uso Android: `flutter build apk`
- Generar binarios compendiados a App Store: `flutter build ios` (Opcional si usas Xcode y perfiles).

> Construida usando buenas prácticas de Dart y componentes seguros actualizados.
