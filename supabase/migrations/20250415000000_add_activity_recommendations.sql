create or replace function trigger_set_timestamp()
returns trigger as
$$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create table if not exists user_activity_surveys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app_users(id) on delete cascade,
  responses jsonb not null,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id)
);

alter table user_activity_surveys enable row level security;

drop policy if exists "public_select_user_activity_surveys" on user_activity_surveys;
create policy "public_select_user_activity_surveys"
  on user_activity_surveys
  for select
  to anon, authenticated
  using (true);

drop policy if exists "public_upsert_user_activity_surveys" on user_activity_surveys;
create policy "public_upsert_user_activity_surveys"
  on user_activity_surveys
  for insert
  to anon, authenticated
  with check (true);

drop policy if exists "public_update_user_activity_surveys" on user_activity_surveys;
create policy "public_update_user_activity_surveys"
  on user_activity_surveys
  for update
  to anon, authenticated
  using (true)
  with check (true);

create trigger set_user_activity_surveys_updated_at
  before update on user_activity_surveys
  for each row execute procedure trigger_set_timestamp();

create table if not exists activity_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app_users(id) on delete cascade,
  activity_name text not null,
  summary text not null,
  location text,
  confidence double precision,
  tags text[] default '{}'::text[] not null,
  created_at timestamptz not null default now()
);

alter table activity_recommendations enable row level security;

drop policy if exists "public_select_activity_recommendations" on activity_recommendations;
create policy "public_select_activity_recommendations"
  on activity_recommendations
  for select
  to anon, authenticated
  using (true);

drop policy if exists "public_insert_activity_recommendations" on activity_recommendations;
create policy "public_insert_activity_recommendations"
  on activity_recommendations
  for insert
  to anon, authenticated
  with check (true);

drop policy if exists "public_delete_activity_recommendations" on activity_recommendations;
create policy "public_delete_activity_recommendations"
  on activity_recommendations
  for delete
  to anon, authenticated
  using (true);

create index if not exists idx_user_activity_surveys_user_id
  on user_activity_surveys (user_id);

create index if not exists idx_activity_recommendations_user_id
  on activity_recommendations (user_id, created_at desc);
