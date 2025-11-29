# Diagrama Entidad-Relación (ER) - App Turismo

Este diagrama muestra la estructura de la base de datos de Supabase con todas las tablas, relaciones y cardinalidades.

```mermaid
erDiagram
    %% Tablas principales
    reports ||--o{ user_preferences : "puede tener"
    safe_routes ||--o{ route_locations : "tiene ubicación"
    safe_routes ||--o{ activity_images : "tiene imágenes"
    
    danger_zones ||--|{ danger_zone_points : "contiene"
    
    activity_survey ||--o{ activity_recommendation : "genera"
    
    %% Tabla: reports
    reports {
        bigint id PK "Auto-increment"
        text type_id "Tipo de reporte"
        text description "Descripción"
        double_precision latitude "Coordenada opcional"
        double_precision longitude "Coordenada opcional"
        timestamptz created_at "Fecha de creación"
    }
    
    %% Tabla: safe_routes
    safe_routes {
        bigint id PK "Auto-increment"
        text name UK "Nombre único"
        text duration "Duración estimada"
        text difficulty "Nivel de dificultad"
        text description "Descripción"
        text_array points_of_interest "Puntos de interés"
        timestamptz created_at
        timestamptz updated_at
    }
    
    %% Tabla: route_locations
    route_locations {
        uuid id PK "UUID"
        text route_name UK "Nombre de ruta"
        double_precision latitude "Coordenada GPS"
        double_precision longitude "Coordenada GPS"
        timestamptz created_at
        timestamptz updated_at
    }
    
    %% Tabla: activity_images
    activity_images {
        uuid id PK "UUID"
        text route_name "Nombre de ruta"
        text activity_name "Nombre de actividad"
        text image_url "URL de imagen"
        int display_order "Orden de visualización"
        timestamptz created_at
    }
    
    %% Tabla: user_preferences
    user_preferences {
        bigint id PK "Auto-increment"
        text preferred_report_type_id "Tipo preferido"
        boolean share_location "Compartir ubicación"
        timestamptz created_at
        timestamptz updated_at
    }
    
    %% Tabla: danger_zones
    danger_zones {
        uuid id PK "UUID"
        text title "Título"
        text description "Descripción"
        text specific_dangers "Peligros específicos"
        text danger_level "high/medium/low"
        text precautions "Precauciones"
        text recommendations "Recomendaciones"
        double_precision latitude "Centro de zona"
        double_precision longitude "Centro de zona"
        double_precision radius "Radio en metros"
        double_precision altitude "Altitud"
        double_precision overlay_height "Altura AR"
        timestamptz created_at
        timestamptz updated_at
    }
    
    %% Tabla: danger_zone_points
    danger_zone_points {
        uuid id PK "UUID"
        uuid zone_id FK "Referencia a zona"
        text title "Título del punto"
        text description "Descripción"
        text precautions "Precauciones"
        text recommendations "Recomendaciones"
        double_precision latitude "Coordenada"
        double_precision longitude "Coordenada"
        double_precision radius "Radio de detección"
        timestamptz created_at
    }
    
    %% Tabla: activity_survey (local/remoto)
    activity_survey {
        string id PK "UUID local"
        string activity_level "Nivel de actividad"
        list preferred_activities "Actividades preferidas"
        datetime timestamp "Fecha de respuesta"
    }
    
    %% Tabla: activity_recommendation (generada por IA)
    activity_recommendation {
        string id PK "UUID"
        string survey_id FK "Referencia a encuesta"
        string activity_name "Nombre de actividad"
        string description "Descripción"
        string location "Ubicación"
        double confidence "Nivel de confianza"
        list reasons "Razones de recomendación"
    }
```

## Relaciones y Cardinalidades

### 1:N (Uno a Muchos)
- **safe_routes → route_locations**: Una ruta tiene una ubicación GPS
- **safe_routes → activity_images**: Una ruta puede tener múltiples imágenes de actividades
- **danger_zones → danger_zone_points**: Una zona de peligro contiene múltiples puntos específicos
- **activity_survey → activity_recommendation**: Una encuesta genera múltiples recomendaciones

### 0:N (Cero a Muchos)
- **reports ← user_preferences**: Las preferencias pueden estar asociadas a reportes (opcional)

## Índices Principales

- `idx_reports_created_at`: Búsqueda por fecha de reportes
- `idx_reports_type_id`: Filtrado por tipo de reporte
- `idx_safe_routes_name`: Búsqueda por nombre de ruta
- `idx_route_locations_route_name`: Búsqueda de ubicaciones por ruta
- `idx_activity_images_route_name`: Filtrado de imágenes por ruta
- `idx_activity_images_display_order`: Ordenamiento de imágenes
- `idx_danger_zones_level`: Filtrado por nivel de peligro
- `idx_danger_zones_location`: Búsqueda geoespacial

## Políticas RLS (Row Level Security)

Todas las tablas tienen RLS habilitado con políticas de:
- **Lectura pública**: Usuarios anónimos y autenticados
- **Escritura autenticada**: Solo usuarios autenticados pueden insertar/actualizar
- **Eliminación autenticada**: Solo usuarios autenticados pueden eliminar

## Storage Buckets

- **activity-images**: Almacenamiento público para imágenes de actividades turísticas
