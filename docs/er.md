// Diagrama ER - App Turismo
// Basado en el esquema SQL de Supabase
// Solo muestra relaciones con FOREIGN KEY explícitas

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
  user_id uuid [not null, ref: > app_users.id]
  preferred_report_type_id text
  share_location bool [not null, default: true]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
}

Table danger_zones {
  id uuid [pk, default: `gen_random_uuid()`]
  title text [not null]
  description text [not null]
  specific_dangers text [not null, default: `''`]
  danger_level text [not null, note: 'CHECK: high, medium, low']
  precautions text [not null, default: `''`]
  recommendations text [not null, default: `''`]
  latitude double [not null]
  longitude double [not null]
  radius double [not null, default: 100]
  altitude double [not null, default: 0]
  overlay_height double [not null, default: 20]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
}

Table danger_zone_points {
  id uuid [pk, default: `gen_random_uuid()`]
  danger_zone_id uuid [not null, ref: > danger_zones.id]
  title text [not null]
  description text [not null, default: `''`]
  precautions text [not null, default: `''`]
  recommendations text [not null, default: `''`]
  latitude double [not null]
  longitude double [not null]
  radius double [not null, default: 30]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
}

// Tablas sin relaciones FK (independientes)

Table safe_routes {
  id bigint [pk, increment]
  name text [not null, unique]
  duration text [not null]
  difficulty text [not null]
  description text [not null]
  points_of_interest text[] [not null, default: `'{}'`]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
}

Table route_locations {
  id uuid [pk, default: `gen_random_uuid()`]
  route_name text [not null, unique]
  latitude double [not null]
  longitude double [not null]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
}

Table activity_images {
  id uuid [pk, default: `gen_random_uuid()`]
  route_name text [not null]
  activity_name text [not null]
  image_url text [not null]
  display_order int [not null, default: 0]
  created_at timestamptz [not null, default: `now()`]
}