-- Plak dit hele script in Supabase > SQL Editor > New query en klik op "Run".
-- Je bestaande gegevens blijven behouden. Veilig om meerdere keren uit te voeren.

-- 1. Extra instellingen voor de bar
alter table config add column if not exists locked boolean not null default false;
alter table config add column if not exists require_approval boolean not null default false;
alter table config add column if not exists session_start timestamptz;
alter table config add column if not exists session_end timestamptz;
alter table config add column if not exists host_name text;

-- 2. Nieuwe tabellen
create table if not exists app_settings (
  id int primary key default 1 check (id = 1),
  main_code text not null default 'abcd'
);
insert into app_settings (id) values (1) on conflict do nothing;

create table if not exists code_requests (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now()
);

create table if not exists room_access (
  id bigint generated always as identity primary key,
  person_name text not null,
  device_id text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

create table if not exists room_requests (
  id bigint generated always as identity primary key,
  first_name text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  require_approval boolean not null default false,
  device_id text not null,
  status text not null default 'pending',
  admin_code text,
  created_at timestamptz not null default now()
);

-- 3. Toegang voor de app
alter table app_settings  enable row level security;
alter table code_requests enable row level security;
alter table room_access   enable row level security;
alter table room_requests enable row level security;

do $$
declare t text;
begin
  foreach t in array array['app_settings','code_requests','room_access','room_requests'] loop
    execute format('drop policy if exists "app_toegang" on %I', t);
    execute format('create policy "app_toegang" on %I for all to anon using (true) with check (true)', t);
  end loop;
end $$;
