# Guía de Configuración de Supabase

Esta guía te ayudará a configurar Supabase en tu proyecto Flutter paso a paso.

## Paso 1: Crear una cuenta en Supabase

1. Ve a [https://supabase.com](https://supabase.com)
2. Haz clic en "Start your project"
3. Crea una cuenta usando tu correo electrónico o GitHub

## Paso 2: Crear un nuevo proyecto

1. Una vez iniciada sesión, haz clic en "New Project"
2. Completa los siguientes campos:
   - **Name**: Nombre de tu proyecto (por ejemplo: "app-turismo")
   - **Database Password**: Crea una contraseña segura (guárdala en un lugar seguro)
   - **Region**: Selecciona la región más cercana a tus usuarios (por ejemplo: "South America (São Paulo)")
   - **Pricing Plan**: Selecciona "Free" para empezar
3. Haz clic en "Create new project"
4. Espera unos minutos mientras Supabase crea tu proyecto

## Paso 3: Obtener las credenciales del proyecto

1. Una vez que tu proyecto esté listo, ve a **Settings** (ícono de engranaje en el menú lateral)
2. Haz clic en **API** en el menú de Settings
3. En la sección "Project API keys", encontrarás:
   - **Project URL**: Esta es tu `SUPABASE_URL`
   - **anon public**: Esta es tu `SUPABASE_ANON_KEY`
4. Copia estos valores (los necesitarás en el siguiente paso)

## Paso 4: Configurar las variables de entorno

1. Abre el archivo `.env` en la raíz de tu proyecto
2. Reemplaza los valores de ejemplo con tus credenciales reales:

```
SUPABASE_URL=https://tu-proyecto-id.supabase.co
SUPABASE_ANON_KEY=tu-anon-key-muy-larga-aqui
```

**IMPORTANTE**:
- NO compartas estas credenciales públicamente
- NO las subas a control de versiones (el archivo `.env` ya está en `.gitignore`)
- Asegúrate de que no haya espacios antes o después de las URLs/keys

## Paso 5: Crear las tablas en Supabase

1. En el panel de Supabase, ve a **SQL Editor** en el menú lateral
2. Haz clic en "New query"
3. Copia todo el contenido del archivo `supabase/migrations/20250101000000_initial_schema.sql`
4. Pégalo en el editor SQL
5. Haz clic en "Run" para ejecutar la migración
6. Verifica que aparezca un mensaje de éxito

## Paso 6: Verificar las tablas creadas

1. Ve a **Table Editor** en el menú lateral de Supabase
2. Deberías ver las siguientes tablas:
   - `reports`: Para almacenar los reportes de los usuarios
   - `safe_routes`: Para almacenar las rutas seguras
   - `user_preferences`: Para almacenar las preferencias del usuario

## Paso 7: Instalar las dependencias de Flutter

En la terminal, dentro de la carpeta del proyecto, ejecuta:

```bash
flutter pub get
```

Este comando instalará todas las dependencias necesarias, incluyendo:
- `supabase_flutter`: Cliente de Supabase para Flutter
- `flutter_dotenv`: Para cargar variables de entorno

## Paso 8: Ejecutar la aplicación

1. Asegúrate de tener un dispositivo conectado o un emulador corriendo
2. Ejecuta la aplicación:

```bash
flutter run
```

## Verificación de la configuración

Si todo está configurado correctamente:

1. La aplicación debería iniciar sin errores
2. Los reportes que crees se guardarán en Supabase
3. Puedes verificar esto yendo a **Table Editor > reports** en el panel de Supabase

## Solución de problemas comunes

### Error: "SUPABASE_URL y SUPABASE_ANON_KEY deben estar configuradas"

**Solución**: Asegúrate de que el archivo `.env` existe en la raíz del proyecto y contiene las credenciales correctas.

### Error: "Failed to load .env"

**Solución**:
1. Verifica que el archivo `.env` esté en la raíz del proyecto
2. Ejecuta `flutter clean` y luego `flutter pub get`
3. Reinicia la aplicación

### Error al conectar con Supabase

**Solución**:
1. Verifica que el `SUPABASE_URL` sea correcto
2. Verifica que el `SUPABASE_ANON_KEY` sea la clave correcta
3. Asegúrate de tener conexión a internet
4. Verifica que tu proyecto de Supabase esté activo

### Error: "relation does not exist"

**Solución**: Las tablas no se crearon correctamente. Repite el Paso 5 para ejecutar la migración SQL.

## Políticas de seguridad (RLS)

Actualmente, las tablas están configuradas con acceso público (cualquier usuario puede leer y escribir).

Si deseas agregar autenticación y restringir el acceso:

1. Ve a **Authentication** en el panel de Supabase
2. Configura los métodos de autenticación que desees
3. Modifica las políticas RLS en **Table Editor > (selecciona tabla) > RLS Policies**

## Próximos pasos

Una vez que todo funcione correctamente, puedes:

1. Personalizar las políticas de seguridad (RLS)
2. Agregar autenticación de usuarios
3. Configurar funciones Edge para lógica del lado del servidor
4. Configurar Storage para almacenar imágenes
5. Agregar subscripciones en tiempo real a los cambios de datos

## Recursos adicionales

- [Documentación oficial de Supabase](https://supabase.com/docs)
- [Documentación de supabase_flutter](https://pub.dev/packages/supabase_flutter)
- [Ejemplos de Flutter con Supabase](https://github.com/supabase/supabase/tree/master/examples/flutter)

## Soporte

Si tienes problemas con la configuración, puedes:
1. Revisar los logs de la aplicación en la consola
2. Consultar la documentación de Supabase
3. Revisar el código en `lib/services/supabase_service.dart`
