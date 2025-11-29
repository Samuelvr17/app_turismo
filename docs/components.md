C4Component
    title Diagrama de Componentes - App Turismo

    Person(user, "Usuario", "Viajero")

    Container_Boundary(flutterApp, "Aplicación Flutter") {
        Component(uiLayer, "UI Layer", "Flutter Widgets", "LoginPage, ActivitySurveyPage, RecommendationsPage")
        Component(servicesLayer, "Services Layer", "Dart Services", "AuthService, StorageService, ActivitySurveyService, WeatherService")
    }

    Container_Boundary(backend, "Backend - Supabase") {
        ComponentDb(database, "PostgreSQL", "PostgreSQL", "app_users, safe_routes, activity_recommendations, reports")
    }

    Container_Boundary(external, "Servicios Externos") {
        Component_Ext(recommendAPI, "Recommendation API", "API", "Motor IA")
        Component_Ext(weatherAPI, "OpenWeatherMap", "REST API", "API Clima")
    }

    Rel(user, uiLayer, "Interactúa")
    Rel(uiLayer, servicesLayer, "Usa")
    Rel(servicesLayer, database, "Lee/Escribe")
    Rel(servicesLayer, recommendAPI, "Genera recomendaciones")
    Rel(servicesLayer, weatherAPI, "Consulta clima")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")