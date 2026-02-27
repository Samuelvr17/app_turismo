Guía Técnica: Realidad Aumentada Basada en Localización (LBAR)

1.	Introducción
¿Qué es la LBAR?
La Location-Based Augmented Reality (Realidad Aumentada Basada en Localización) es un tipo de realidad aumentada donde la información que aparece superpuesta en la pantalla no está ligada a ningún objeto físico especial, sino a coordenadas geográficas reales del mundo real (latitud y longitud).
En otras palabras, en lugar de apuntar la cámara a un marcador impreso en papel para que aparezca algo, el sistema sabe dónde está el usuario en el mundo y qué hay alrededor gracias al GPS y a los sensores del dispositivo. Si hay un punto de peligro registrado a 150 metros al norte, la aplicación lo "ve" aunque el usuario no pueda verlo a simple vista.

¿Qué problema resuelve en la app?
La aplicación contiene un mapa de zonas y puntos de peligro urbano (como zonas de riesgo de seguridad, accidentes, etc.). Sin AR, el usuario necesita mirar el mapa 2D y mentalmente ubicarse en el espacio. Con LBAR, el usuario puede apuntar la cámara de su celular hacia cualquier dirección y ver, superpuestos sobre la imagen real de la cámara, los puntos de peligro que hay en esa dirección y a qué distancia se encuentran.

¿En qué se diferencia de la AR con marcadores físicos?
Característica	AR con marcadores físicos	AR basada en localización
Requiere imprimir o mostrar algo	Sí (un código QR, una imagen especial)	No
Funciona en exteriores	Parcialmente	Sí, es su entorno natural
Usa GPS	No	Sí, es fundamental
Usa la brújula del dispositivo	No necesariamente	Sí, siempre
Depende de lo que "vea" la cámara	Sí (necesita reconocer el marcador)	No (los objetos son invisibles, basados en coordenadas)

En este proyecto no se usa AR con marcadores. Todo el sistema funciona con sensores del dispositivo: GPS, brújula y acelerómetro.


2.	Conceptos Clave
Para entender cómo funciona el sistema es necesario comprender cuatro conceptos fundamentales. Todos son ángulos medidos en grados (°), igual que en una brújula.
Bearing (Rumbo geográfico)
El bearing es el ángulo, medido en grados desde el norte geográfico (0°), que indica en qué dirección se encuentra un punto específico cuando se mira desde la posición del usuario.
Por ejemplo, si una zona de peligro está exactamente al este de donde estoy parado, su bearing es 90°. Si está al sur, es 180°. Si está al norte, es 0° o 360°.
Este valor lo calcula la app usando las coordenadas GPS del usuario y del punto de peligro. Es completamente independiente de hacia dónde está mirando el usuario.

Heading (Orientación del dispositivo)
El heading es el ángulo que indica hacia qué dirección está apuntando la cámara del dispositivo en este momento. También se mide desde el norte (0°) en sentido horario.
Si el usuario está mirando hacia el este, su heading es ≈ 90°. Si está mirando al sur, ≈ 180°.
Este valor lo proporciona la brújula electrónica del teléfono en tiempo real. En el código, `_heading` se actualiza continuamente mediante el stream del sensor de FlutterCompass.


Rumbo Relativo (Relative Bearing)
El rumbo relativo es la diferencia entre el bearing de un punto y el heading actual del dispositivo. Es decir, esto responde a la pregunta: ¿Qué tan desviado estoy de mirar directamente hacia ese punto?
- Si el rumbo relativo es 0°, el usuario está mirando directamente hacia el punto de peligro.
- Si es -30°, el punto está 30° a su izquierda.
- Si es +45°, el punto está 45° a su derecha.
Este es el valor más importante del sistema, pues a partir de él se decide si un punto debe mostrarse en pantalla o no, y dónde.}
Matemáticamente: rumbo relativo = bearing - heading, normalizado al rango [-180°, +180°].

FOV - Field of View (Campo de visión)
El FOV es el ángulo que abarca el lente de la cámara. Si la cámara tiene un FOV horizontal de 60°, eso significa que puede capturar todo lo que hay en un cono de 30° a la izquierda y 30° a la derecha del centro de la imagen.
En el sistema LBAR, el FOV determina qué puntos "entran" en la pantalla y cuáles quedan fuera de cuadro. Un punto con rumbo relativo de +20° sí aparece en una cámara con FOV de 60° (porque 20° < 30°). Uno con rumbo relativo de +50° no aparecería porque está fuera del campo visual.
El FOV también dicta cómo se convierte el ángulo de un punto en una posición de píxeles sobre la pantalla.





3.	Tecnologías y Librerías Utilizadas
Librería	Versión	Para qué se usa en este proyecto
camera	^0.11.0+2	Acceder a la cámara trasera del dispositivo y mostrar el feed en vivo como fondo de la vista AR
flutter_compass	^0.8.0	Leer la brújula electrónica del teléfono para obtener el heading (orientación) en tiempo real
geolocator	^14.0.2	Obtener la posición GPS del usuario con alta precisión y calcular distancias y bearings entre coordenadas
sensors_plus	^5.0.1	Leer el acelerómetro para calcular el pitch (inclinación vertical del teléfono)
google_maps_flutter	^2.13.1	Mostrar el mapa interactivo con las zonas de peligro y proporcionar la clase LatLng para trabajar con coordenadas
permission_handler	^12.0.1	Solicitar en tiempo de ejecución los permisos de cámara y ubicación al usuario
vector_math	^2.1.4	Operaciones matemáticas de vectores y matrices (disponible para futuros cálculos de rotación 3D)
supabase_flutter	^2.10.3	Obtener desde la base de datos remota la lista de zonas y puntos de peligro con sus coordenadas


4.	Modelo de Datos de las Zonas de Peligro
El sistema maneja dos clases principales para representar la información geográfica de peligro. Una zona agrupa a varios puntos específicos dentro de ella.

Clase “DangerZone” (Zona de Peligro)
Representa un área geográfica catalogada como peligrosa.
Campo	Tipo	Descripción
id	String	Identificador único de la zona
center	LatLng	Coordenadas del centro geográfico de la zona
title	String	Nombre descriptivo de la zona
description	String	Descripción general del riesgo
specificDangers	String	Tipos de peligro específicos presentes en el área
precautions	String	Medidas de precaución recomendadas
securityRecommendations	String	Recomendaciones detalladas de seguridad
level	DangerLevel	Nivel de peligro: high, médium, low 
points	List<DangerZonePoint>	Lista de puntos específicos de peligro dentro de esta zona
radius	double	Radio en metros de la zona (por defecto: 100 m)
altitude	double	Altitud en metros (para uso en cálculos verticales)
overlayHeight	double	Altura visual del overlay en la vista AR 

El campo “level” se usa en la vista AR para colorear las alertas: rojo para “high”, naranja para “médium” y amarillo para “low”.

Clase “DangerZonePoint” (Punto de Peligro)
Representa un punto específico y preciso dentro de una zona
Campo	Tipo	Descripción
id	String	Identificador único del punto
dangerZoneId	String	ID de la zona a la que pertenece este punto
title	String	Nombre descriptivo del punto
description	String	Descripción del peligro en ese punto exacto
precautions	String	Precauciones específicas para ese punto
recommendations	String	Recomendaciones específicas para ese punto
location	LatLng	Coordenadas exactas del punto (latitud y longitud)
radius	double	Radio de detección del punto en metros




Lógica de Activación del Overlay
El overlay (capa de información superpuesta) se muestra en la vista AR siguiendo estas reglas:
A. Filtro por distancia general: Solo se consideran los puntos que estén dentro de un radio de 1.200 metros del usuario. Puntos más lejanos simplemente no se procesan, esto ahorra cómputo y evita ruido visual.
B. Filtro por FOV: De los puntos cercanos, solo los que tienen un rumbo relativo de ±20° o menos son candidatos a mostrar el overlay destacado. En otras palabras, el punto debe estar "casi frente a la cámara" (dentro de un cono de ±20°).
C. Filtro por distancia de activación: Dentro del FOV, el overlay destacado solo se activa si el usuario está a una distancia menor o igual a: “distancia_activacion = MAX(radio_del_punto, 200 metros)”
El mínimo de 200 m garantiza que se muestre advertencia temprana incluso para puntos con radio muy pequeño (p.ej. 30 m), lo cual tendría poco sentido esperar hasta estar a solo 30 m.
D. Prioridad por proximidad: Si hay varios puntos que cumplen todos los criterios anteriores, se muestra el overlay del punto más cercano. Los demás se listan en el panel inferior.


5.	La Matemática Detrás del Sistema
Esta sección explica paso a paso los cálculos que realiza el sistema para decidir si un punto de peligro debe aparecer en pantalla y en qué posición exacta.
Paso 1: Calcular la distancia al punto
El primer filtro es la distancia. Se usa la fórmula de Haversine, que calcula la distancia en línea recta entre dos coordenadas sobre la superficie de la Tierra (considerando su curvatura). En el código, esta operación es delegada completamente a “Geolocator.distanceBetween()”, que implementa esta fórmula internamente.
El resultado es la distancia en metros entre la posición del usuario y el punto de peligro. Cualquier punto a más de 1.200 m se descarta inmediatamente.
Paso 2: Calcular el bearing al punto
El bearing (rumbo geográfico hacia el punto) se calcula también mediante “Geolocator.bearingBetween()”. Internamente, esta función usa trigonometría esférica con la siguiente lógica:
```
Δλ = longitud_destino - longitud_origen (en radianes)
x = cos(lat_destino) × sin(Δλ)
y = cos(lat_origen) × sin(lat_destino) - sin(lat_origen) × cos(lat_destino) × cos(Δλ)
bearing = atan2(x, y) → convertido a grados y normalizado a [0°, 360°)
```
El bearing es un ángulo fijo en el mundo, si la zona está al noreste de mi posición, su bearing es ≈ 45°, sin importar hacia dónde esté mirando yo.
Paso 3: Calcular el rumbo relativo
Una vez conocido el bearing del punto y el heading actual del dispositivo, se calcula el rumbo relativo:
```
rumbo_relativo = bearing - heading
```
Sin embargo, este resultado puede quedar fuera del rango [-180°, +180°], por lo que se normaliza:
```
double normalized = (bearing - heading) % 360;
if (normalized > 180)  normalized -= 360;
if (normalized < -180) normalized += 360;
```
Este cálculo se realiza en el método `_relativeBearing()` de `_ArCameraViewState`. El resultado indica si el punto está a la izquierda (negativo) o derecha (positivo) de lo que está viendo la cámara, y en cuántos grados.

Paso 4: Determinar si el punto está en el FOV
La comprobación es simple: si el valor absoluto del rumbo relativo es menor o igual a la mitad del FOV horizontal, el punto está dentro del campo visual de la cámara.
Con un FOV de 60°, el umbral es 30°. Con el umbral de 20° usado para activar el overlay destacado (que es más conservador que el FOV completo):
```
punto_en_FOV = |rumbo_relativo| <= 20°
```

Paso 5: Calcular la posición en píxeles en la pantalla
Para saber exactamente dónde colocar un marcador en la pantalla (su coordenada X horizontal), se hace una proyección lineal del rumbo relativo sobre el ancho de la pantalla:
```
xRatio = 0.5 - (rumbo_relativo / FOV_horizontal)
x_en_pixeles = xRatio × ancho_pantalla
```


6.	Flujo Completo de Ejecución
Este es el recorrido completo desde que el usuario toca el botón hasta que ve la información en pantalla.


Paso 1 - El usuario pulsa "Ver en AR"
En la pantalla del mapa (`MapaPage`), hay un botón flotante con el texto "Ver en AR" y el icono de realidad aumentada. Al pulsarlo, se invoca el método `_openArDangerView()`.
Paso 2 - Verificación de GPS
El método comprueba si hay una posición GPS disponible. Si el GPS no está activo o no ha obtenido señal aún, muestra un mensaje de aviso y detiene el proceso.
Paso 3 - Solicitud de permiso de cámara
Se solicita al sistema Android permiso para usar la cámara (`Permission.camera.request()`). Si el usuario lo deniega, se muestra un aviso y se detiene el proceso.
Paso 4 - Recopilación de zonas cercanas
Se llama a `ZoneDetectionService.collectNearbyZones()` para filtrar de toda la lista de zonas solo las que están dentro de un radio de **1.000 metros** de la posición actual del usuario. Esto optimiza la cantidad de datos que se pasan a la vista AR.
Paso 5 - Navegación a la vista AR
Con la lista de zonas cercanas y la posición actual, se navega al widget `ArCameraView` usando `Navigator.push()`. Se pasa la lista de zonas y la posición inicial del usuario como parámetros obligatorios.
Paso 6 - Inicialización de la vista AR
Al iniciarse `ArCameraView`, ocurren cuatro cosas en paralelo:
- Se inicializa la cámara trasera con resolución media (`ResolutionPreset.medium`) y sin audio.
- Se inicia el stream de GPS (`Geolocator.getPositionStream`) con la máxima precisión y se actualiza la posición cuando el usuario se mueve más de 5 metros.
- Se suscribe al stream de la brújula (`FlutterCompass.events`) para actualizar `_heading` continuamente.
- Se suscribe al stream del acelerómetro (`accelerometerEventStream`) para calcular el `_pitch` en tiempo real.
Paso 7 - Renderizado continuo
Cada vez que se actualiza el heading, el pitch o la posición, el widget se reconstruye (mediante `setState`). Para no sobrecargar la interfaz, se aplica un throttle (regulador de frecuencia) que limita las actualizaciones.
Paso 8 - Cálculo y filtrado de puntos
En cada reconstrucción del widget, la función `_pointsWithinRadius()` recorre todos los puntos de todas las zonas cercanas, calcula su distancia y rumbo relativo respecto a la posición y heading actuales, y devuelve solo los que están dentro del radio de 1.200 m, ordenados por proximidad.
Paso 9 - Lógica del overlay destacado
De esa lista filtrada, se busca si algún punto cumple los tres criterios de activación (FOV ±20°, distancia de activación, más cercano). Si lo hay, se muestra el widget `_FocusedPointOverlay` con nombre, distancia, descripción, precauciones y recomendaciones. Si no, ese espacio queda vacío.
Paso 10 - Panel de puntos cercanos
Independientemente del overlay destacado, siempre se muestra en la parte inferior de la pantalla un panel con la lista completa de puntos dentro del radio de 1.200 m, con flecha direccional giratoria, nombre, zona y distancia.







7.	Permisos Requeridos en Android
Los permisos están declarados en el archivo `android/app/src/main/AndroidManifest.xml`:
`ACCESS_FINE_LOCATION` - Ubicación precisa
Permite que la app obtenga la posición GPS del dispositivo con alta precisión (metros). Es indispensable para calcular distancias reales y bearings correctos.
```
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```
`ACCESS_COARSE_LOCATION` - Ubicación aproximada
Permite ubicación basada en redes Wi-Fi y torres celulares (menos precisa). Se declara como complemento al permiso fino, y es requerida por algunas versiones del sistema cuando se solicita `FINE_LOCATION`.
```
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```
`CAMERA` - Uso de la cámara
Permite acceder al hardware de cámara del dispositivo para mostrar el feed en vivo como fondo de la vista AR.
```
<uses-permission android:name="android.permission.CAMERA" />
```
Declaraciones de hardware (features)
Además de los permisos, el manifest declara qué hardware usa la app. Al marcarse como `required="false"`, la app puede instalarse en dispositivos que no tengan ese hardware, aunque esa funcionalidad específica quede deshabilitada:
```
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
<uses-feature android:name="android.hardware.camera.ar" android:required="false" />
<uses-feature android:name="android.hardware.sensor.accelerometer" android:required="false" />
<uses-feature android:name="android.hardware.sensor.gyroscope" android:required="false" />
```
Nota: Los permisos de cámara y ubicación son permisos de tiempo de ejecución en Android (desde Android 6.0). Esto significa que la app debe solicitarlos explícitamente al usuario en el momento de usarlos, no solo declararlos en el manifest. Esto se hace mediante la librería `permission_handler`.


8.	Cómo Probar la Funcionalidad AR en Android
Requisitos previos
- Dispositivo Android físico (la funcionalidad no es probable en el emulador pues no tiene sensor de brújula real ni GPS físico).
- La app instalada y corriendo en modo debug o release.
- GPS del dispositivo activado.
- Permiso de cámara y ubicación concedidos.

Pasos para probar en dispositivo físico
1. Conectar el dispositivo al computador con cable USB y activar la depuración USB en las opciones de desarrollador o bien de manera inalámbrica.
2. Ejecutar la app la terminal con el comando: Se recomienda `flutter run --release` para que los sensores respondan con mayor fluidez (en debug hay más latencia).

3. Una vez en la pantalla del mapa, esperar a que el GPS obtenga señal (el marcador de posición azul debe aparecer en el mapa). 
4. Pulsar el botón "Ver en AR" en la esquina inferior derecha.
5. Conceder los permisos de cámara y ubicación si el sistema los solicita.
6. La vista AR debe abrirse mostrando:
   - El feed de la cámara trasera como fondo.
   - Un panel inferior con los puntos cercanos y sus flechas direccionales.
   - El panel de estado en la parte inferior con los valores actuales de Heading, Pitch y GPS.

¿Cómo verificar que los sensores funcionan correctamente?
Brújula (Heading): En el panel de estado inferior, el campo "Heading" debe cambiar de valor suavemente al girar el teléfono horizontalmente. Si permanece en 0° sin importar la orientación, la brújula puede necesitar calibración: hacer el movimiento de 8 acostado en el aire con el teléfono 3-5 veces.
Acelerómetro (Pitch): El campo "Pitch" debe cambiar al inclinar el teléfono hacia arriba o abajo. Un valor de ≈0° indica el teléfono horizontal, ≈90° vertical apuntando al suelo, ≈-90° vertical apuntando al cielo.
GPS: Las coordenadas en el campo "GPS" deben corresponder a la ubicación real del probador. Si el GPS no tiene señal, se mostrará "Sin señal".
Flechas direccionales: Las flechas de los puntos en el panel inferior deben rotar al girar el cuerpo del usuario. Una flecha apuntando hacia arriba indica que ese punto está directamente frente a la cámara.



¿Qué hacer si no hay zonas de peligro cercanas para testear?
Si el probador se encuentra en un lugar donde no hay zonas en la base de datos, hay dos alternativas:
Opción A - Insertar datos de prueba en Supabase:
Ingresar al panel de administración de Supabase del proyecto y crear manualmente una zona de peligro en las coordenadas actuales del dispositivo de prueba. Crear también al menos un `DangerZonePoint` asociado a esa zona, con coordenadas a unos 100-150 metros del probador.
Después de insertar los datos, volver a la pantalla del mapa, esperar unos segundos a que recargue las zonas (o salir y volver a entrar a la pantalla) y volver a abrir la vista AR.

Opción B - Modificar temporalmente el código para pruebas:
En el método `_openArDangerView()` de `mapa_page.dart`, se puede reemplazar temporalmente la lista de zonas con datos hardcodeados de prueba que tengan las coordenadas actuales del dispositivo de prueba. Esta opción es útil para pruebas rápidas sin acceso al panel de Supabase, pero debe revertirse antes de hacer commit.
Verificar el overlay destacado: Para ver el overlay de zona enfocada (`_FocusedPointOverlay`), debe orientarse directamente hacia un punto de peligro (que el Heading apunte hacia el bearing del punto, dejando el rumbo relativo en ≈0°) y estar dentro de la distancia de activación (la mayor entre el radio del punto y 200 m). El panel de estado inferior mostrará el bearing de cada punto, lo que ayuda a orientarse.


