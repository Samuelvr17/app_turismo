---
config:
  theme: default
  layout: elk
---
classDiagram
    %% ==========================================
    %% MODELOS PRINCIPALES
    %% ==========================================
    
    class AppUser {
        +String id
        +String email
        +String? fullName
        +toJson()
        +fromJson()
    }

    class SafeRoute {
        +String name
        +String duration
        +String difficulty
        +String description
        +List~String~ pointsOfInterest
    }

    class ActivityRecommendation {
        +String activityName
        +String summary
        +double? confidence
        +List~String~ tags
    }

    class WeatherData {
        +double temperature
        +String description
        +String windDirection
    }

    class Report {
        +String id
        +String typeId
        +String description
        +double? latitude
        +double? longitude
    }

    %% ==========================================
    %% SERVICIOS CORE
    %% ==========================================

    class AuthService {
        -SupabaseClient _supabase
        -AppUser? _currentUser
        +login(email, password)
        +register(email, password)
        +logout()
        +currentUserListenable
    }

    class RouteDataService {
        <<singleton>>
        -SupabaseClient _supabase
        -Map~String, LatLng~ _cachedLocations
        -Map _cachedImages
        +getRouteLocations()
        +getAllActivityImages()
    }

    class WeatherService {
        <<singleton>>
        -WeatherData? _currentWeather
        +getWeatherByCoordinates(lat, lon)
        +startAutoUpdate(lat, lon)
        +weatherListenable
    }

    class ActivitySurveyService {
        -RecommendationApiService _api
        -List~ActivityRecommendation~ _recommendations
        +submitSurvey(survey)
        +refreshRecommendations()
    }

    class StorageService {
        -LocalStorageService _local
        -SupabaseClient _remote
        +saveReport(type, description)
        +loadSafeRoutes()
        +saveUserPreferences(prefs)
    }

    %% ==========================================
    %% INTERFACES Y ABSTRACCIONES
    %% ==========================================

    class ReportsRemoteDataSource {
        <<interface>>
        +getReports(userId)*
        +saveReport(userId, type, desc)*
        +getSafeRoutes()*
    }

    class SupabaseService {
        +getReports(userId)
        +saveReport(userId, type, desc)
        +getSafeRoutes()
        +getUserPreferences(userId)
    }

    %% ==========================================
    %% RELACIONES PRINCIPALES
    %% ==========================================

    AuthService --> AppUser : mantiene
    AuthService --> SupabaseService : usa

    RouteDataService --> SafeRoute : carga
    RouteDataService --> SupabaseService : consulta

    WeatherService --> WeatherData : mantiene

    ActivitySurveyService --> ActivityRecommendation : produce
    ActivitySurveyService --> SafeRoute : lee

    StorageService --> Report : gestiona
    StorageService --> ReportsRemoteDataSource : usa
    StorageService --> SafeRoute : sincroniza

    SupabaseService ..|> ReportsRemoteDataSource : implementa

    AppUser --> ActivityRecommendation : recibe
    AppUser --> Report : crea