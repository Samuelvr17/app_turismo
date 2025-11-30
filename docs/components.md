C4Component
    title Diagrama de Componentes - App Turismo

    Person(user, "Usuario", "Turista/Viajero")

    Container_Boundary(flutterApp, "Aplicación Flutter") {
        Component(uiLayer, "UI Layer", "Flutter Widgets", "Pages: Login, Survey, Recommendations, Routes, AR")
        Component(servicesLayer, "Services Layer", "Dart Services", "Auth, Storage, Weather, Survey, RouteData")
        Component(localStorage, "Local Storage", "Hive + SharedPrefs", "Cache offline de rutas e imágenes")
    }

    Container_Boundary(backend, "Backend - Supabase") {
        ComponentDb(database, "PostgreSQL", "PostgreSQL", "users, routes, activity_images, route_locations, reports")
        ComponentDb(storage, "Supabase Storage", "Object Storage", "Bucket: activity-images (público)")
        Component(auth, "Supabase Auth", "Auth Service", "JWT + RLS")
    }

    Container_Boundary(external, "Servicios Externos") {
        Component_Ext(recommendAPI, "Recommendation API", "FastAPI", "Motor IA con scoring heurístico")
        Component_Ext(weatherAPI, "OpenWeatherMap", "REST API", "Datos meteorológicos")
    }

    Container_Boundary(hardware, "Hardware/Sensores") {
        Component_Ext(gps, "GPS", "Sensor", "Geolocalización")
        Component_Ext(sensors, "IMU Sensors", "Gyro/Compass", "AR y orientación")
    }

    Rel(user, uiLayer, "Interactúa con")
    Rel(uiLayer, servicesLayer, "Usa servicios")
    Rel(servicesLayer, localStorage, "Lee/Escribe cache")
    
    Rel(servicesLayer, database, "CRUD datos", "Supabase Client")
    Rel(servicesLayer, storage, "Descarga imágenes", "HTTPS")
    Rel(servicesLayer, auth, "Autenticación", "JWT")
    
    Rel(servicesLayer, recommendAPI, "Genera recomendaciones", "HTTP POST")
    Rel(servicesLayer, weatherAPI, "Consulta clima", "HTTP GET")
    
    Rel(servicesLayer, gps, "Lee ubicación")
    Rel(servicesLayer, sensors, "Lee orientación")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")