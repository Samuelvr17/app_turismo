C4Component
    title Diagrama de Componentes - App Turismo

    Person(user, "Usuario", "Turista/Usuario")

    Container_Boundary(flutterApp, "Aplicación Flutter") {
        Component(uiLayer, "UI Layer", "Flutter Widgets", "Paginas App")
        Component(servicesLayer, "Services Layer", "Dart Services", "Servicios App")
        Component(localStorage, "Local Storage", "Hive + SharedPrefs", "Cache offline")
    }

    Container_Boundary(backend, "Backend - Supabase") {
        ComponentDb(database, "PostgreSQL", "PostgreSQL", "Entidades")
        ComponentDb(storage, "Supabase Storage", "Object Storage", "activity-images")
        Component(auth, "Supabase Auth", "Auth Service", "JWT + RLS")
    }

    Container_Boundary(external, "Servicios Externos") {
        Component_Ext(recommendAPI, "Recommendation API", "FastAPI")
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

UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")
    UpdateElementStyle(uiLayer, $bgColor="#4A90E2", $fontColor="#FFFFFF")
    UpdateElementStyle(servicesLayer, $bgColor="#4A90E2", $fontColor="#FFFFFF")
    UpdateElementStyle(localStorage, $bgColor="#4A90E2", $fontColor="#FFFFFF")
    UpdateElementStyle(database, $bgColor="#2874A6", $fontColor="#FFFFFF")
    UpdateElementStyle(storage, $bgColor="#2874A6", $fontColor="#FFFFFF")
    UpdateElementStyle(auth, $bgColor="#2874A6", $fontColor="#FFFFFF")
    UpdateElementStyle(recommendAPI, $bgColor="#6B7280", $fontColor="#FFFFFF")
    UpdateElementStyle(weatherAPI, $bgColor="#6B7280", $fontColor="#FFFFFF")
    UpdateElementStyle(gps, $bgColor="#6B7280", $fontColor="#FFFFFF")
    UpdateElementStyle(sensors, $bgColor="#6B7280", $fontColor="#FFFFFF")