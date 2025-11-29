---
config:
  theme: default
  layout: elk
---
classDiagram
    %% ==========================================
    %% AUTENTICACIÓN Y USUARIO
    %% ==========================================
    
    class AppUser {
        +String id
        +String email
        +String? fullName
        +toJson()
        +fromJson()
        +copyWith()
    }

    class AuthService {
        -SupabaseService _supabase
        -AppUser? _currentUser
        +login(email, password)
        +register(email, password, fullName)
        +logout()
        +currentUserListenable
    }

    %% ==========================================
    %% SERVICIOS DE UBICACIÓN Y CLIMA
    %% ==========================================

    class LocationState {
        +double? latitude
        +double? longitude
        +bool hasPermission
    }

    class LocationService {
        -LocationState _state
        +getCurrentPosition()
        +startLocationStream()
        +locationListenable
    }

    class WeatherData {
        +double temperature
        +String description
        +String windDirection
    }

    class WeatherService {
        -WeatherData? _weatherData
        +updateWeather(lat, lon)
        +weatherListenable
    }

    %% ==========================================
    %% ENCUESTAS Y RECOMENDACIONES
    %% ==========================================

    class ActivitySurvey {
        +String travelStyle
        +List~String~ interests
        +String activityLevel
        +String budgetLevel
        +toJson()
        +copyWith()
    }

    class ActivityRecommendation {
        +String activityName
        +String summary
        +double? confidence
        +List~String~ tags
        +DateTime createdAt
    }

    class ActivitySurveyService {
        -RecommendationApiService _apiService
        -ActivitySurvey? _survey
        -List~ActivityRecommendation~ _recommendations
        +submitSurvey(survey)
        +refreshRecommendations()
        +surveyListenable
        +recommendationsListenable
    }

    class RecommendationApiService {
        +generateRecommendations(userId, survey, activities)
    }

    %% ==========================================
    %% RUTAS Y ACTIVIDADES
    %% ==========================================

    class SafeRoute {
        +String name
        +String duration
        +String difficulty
        +String description
        +List~String~ pointsOfInterest
    }

    class AvailableActivity {
        +String name
        +String routeName
        +String routeDifficulty
        +fromSafeRoute(route, activityName)
        +toJson()
    }

    %% ==========================================
    %% REPORTES Y PREFERENCIAS
    %% ==========================================

    class Report {
        +String id
        +String typeId
        +String description
        +DateTime createdAt
        +double? latitude
        +double? longitude
    }

    class UserPreferences {
        +String? preferredReportTypeId
        +bool shareLocation
        +toJson()
    }

    %% ==========================================
    %% CAPA DE DATOS
    %% ==========================================

    class StorageService {
        -LocalStorageService _localStorage
        -ReportsRemoteDataSource _remote
        +saveReport(type, description)
        +deleteReport(id)
        +loadSafeRoutes()
        +saveUserPreferences(preferences)
    }

    class LocalStorageService {
        -List~Report~ _reports
        -UserPreferences _preferences
        +saveReport(report)
        +cacheUserPreferences(preferences)
        +reports
    }

    class ReportsRemoteDataSource {
        <<interface>>
        +getReports(userId)
        +getSafeRoutes()
        +saveReport(userId, type, description)
    }

    class SupabaseService {
        +getReports(userId)
        +getSafeRoutes()
        +saveReport(userId, type, description)
        +getUserPreferences(userId)
    }

    %% ==========================================
    %% RELACIONES PRINCIPALES
    %% ==========================================

    %% Autenticación
    AuthService --> SupabaseService : usa
    AuthService --> AppUser : mantiene

    %% Servicios de contexto
    LocationService --> LocationState : gestiona
    WeatherService --> WeatherData : mantiene

    %% Encuestas y Recomendaciones
    AppUser --> ActivitySurvey : tiene
    AppUser --> ActivityRecommendation : recibe
    ActivitySurveyService --> ActivitySurvey : gestiona
    ActivitySurveyService --> ActivityRecommendation : produce
    ActivitySurveyService --> RecommendationApiService : consulta
    ActivitySurveyService --> SafeRoute : lee

    %% Rutas y Actividades
    SafeRoute --> AvailableActivity : genera

    %% Almacenamiento
    AppUser --> StorageService : inicializa
    StorageService *-- LocalStorageService : contiene
    StorageService --> ReportsRemoteDataSource : usa
    StorageService --> Report : gestiona
    StorageService --> UserPreferences : maneja
    StorageService --> SafeRoute : sincroniza
    LocalStorageService --> Report : cachea
    LocalStorageService --> UserPreferences : persiste
    SupabaseService ..|> ReportsRemoteDataSource : implementa