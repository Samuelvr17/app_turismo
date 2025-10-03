-- Habilita la generación de UUID si todavía no lo has hecho
create extension if not exists pgcrypto;

-- Tabla de usuarios utilizada por AuthService
create table if not exists app_users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  password_hash text not null,
  full_name text,
  created_at timestamptz not null default now()
);

alter table app_users enable row level security;

-- Políticas abiertas para poder registrar y validar usuarios desde el cliente.
-- Ajusta estas políticas cuando integres un esquema de autenticación más estricto.
create policy if not exists "anon_can_select_app_users"
  on app_users
  for select
  to anon, authenticated
  using (true);

create policy if not exists "anon_can_insert_app_users"
  on app_users
  for insert
  to anon, authenticated
  with check (true);

-- Asociar la información existente con el usuario autenticado
alter table reports
  add column if not exists user_id uuid references app_users(id) on delete cascade;

alter table safe_routes
  add column if not exists user_id uuid references app_users(id) on delete cascade;

alter table user_preferences
  add column if not exists user_id uuid references app_users(id) on delete cascade;

-- Si ya tienes filas antiguas, rellena primero user_id antes de forzar NOT NULL
alter table reports alter column user_id set not null;
alter table safe_routes alter column user_id set not null;
alter table user_preferences alter column user_id set not null;

-- Índices y restricciones que usan los upserts del código
create index if not exists idx_reports_user_id_created_at
  on reports (user_id, created_at desc);

create index if not exists idx_reports_user_id
  on reports (user_id);

create unique index if not exists safe_routes_user_id_name_key
  on safe_routes (user_id, name);

create unique index if not exists user_preferences_user_id_key
  on user_preferences (user_id);
