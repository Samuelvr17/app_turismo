Table app_users {
  id uuid [pk, default: `gen_random_uuid()`]
  email text [not null, unique]
  password_hash text [not null]
  full_name text
  created_at timestamptz [not null, default: `now()`]
}

Table activity_recommendations {
  id uuid [pk, default: `gen_random_uuid()`]
  user_id uuid [not null, ref: > app_users.id]
  activity_name text [not null]
  summary text [not null]
  location text
  confidence double
  tags text[] [not null, default: `'{}'`]
  created_at timestamptz [not null, default: `now()`]
}

Table reports {
  id bigint [pk, increment]
  type_id text [not null]
  description text [not null]
  latitude double
  longitude double
  created_at timestamptz [not null, default: `now()`]
  user_id uuid [not null, ref: > app_users.id]
}

Table safe_routes {
  id bigint [pk, increment]
  name text [not null, unique]
  duration text [not null]
  difficulty text [not null]
  description text [not null]
  points_of_interest text[] [not null, default: `'{}'`]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  
  Note: '''
  Tabla global de rutas turísticas seguras.
  NO tiene user_id - todas las rutas son públicas.
  Todos los usuarios ven las mismas rutas.
  Solo admins/desarrolladores crean rutas manualmente.
  '''
}

Table route_locations {
  id bigint [pk, increment]
  route_name text [not null, unique]
  latitude double [not null]
  longitude double [not null]
  created_at timestamptz [not null, default: `now()`]
  
  Note: '''
  Ubicaciones GPS de las rutas turísticas.
  Relación 1:1 con safe_routes por route_name.
  '''
}

Table activity_images {
  id bigint [pk, increment]
  route_name text [not null]
  activity_name text [not null]
  image_url text [not null]
  display_order int [not null, default: 1]
  created_at timestamptz [not null, default: `now()`]
  
  Indexes {
    (route_name, activity_name) [name: 'idx_activity_images_route_activity']
  }
  
  Note: '''
  Imágenes de actividades por ruta.
  image_url puede ser:
  - URL de Supabase Storage (https://...)
  - URL externa (Unsplash, etc)
  Relación N:M entre rutas y actividades.
  '''
}

Table danger_zones {
  id bigint [pk, increment]
  name text [not null]
  description text [not null]
  latitude double [not null]
  longitude double [not null]
  radius_meters int [not null, default: 100]
  danger_level text [not null]
  created_at timestamptz [not null, default: `now()`]
  
  Note: '''
  Zonas de peligro para AR.
  Mostradas en vista de realidad aumentada.
  '''
}

Table user_activity_surveys {
  id uuid [pk, default: `gen_random_uuid()`]
  user_id uuid [not null, unique, ref: > app_users.id]
  responses jsonb [not null]
  completed_at timestamptz [not null, default: `now()`]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
}

Table user_preferences {
  id bigint [pk, increment]
  preferred_report_type_id text
  share_location boolean [not null, default: true]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  user_id uuid [not null, ref: > app_users.id]
}

// Relaciones implícitas (sin FK explícitas)
Ref: route_locations.route_name - safe_routes.name
Ref: activity_images.route_name > safe_routes.name