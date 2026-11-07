-- Plak dit hele script in Supabase > SQL Editor > New query en klik op "Run".
-- Veilig om meerdere keren uit te voeren. Voer eerst supabase-update.sql uit als je dat nog niet deed.

-- 1. Extra gegevens bij een bar-aanvraag
alter table room_requests add column if not exists email text;
alter table room_requests add column if not exists requested_code text;
alter table room_requests add column if not exists clear_on_start boolean not null default true;
alter table room_requests add column if not exists applied boolean not null default false;

-- 2. Functies die op de server draaien, zodat de codes geheim blijven
create or replace function check_staff_code(p_code text) returns boolean
language sql security definer set search_path = public stable as $$
  select coalesce((select staff_code = p_code from config where id = 1), false)
$$;

create or replace function check_main_code(p_code text) returns boolean
language sql security definer set search_path = public stable as $$
  select coalesce((select main_code = p_code from app_settings where id = 1), false)
$$;

-- Zet de gekozen beheerderscode (en de sessietijden) aan zodra een goedgekeurde sessie begint
create or replace function apply_due_sessions() returns void
language plpgsql security definer set search_path = public as $$
declare r room_requests%rowtype;
begin
  select * into r from room_requests
   where status = 'approved' and applied = false and requested_code is not null
     and start_at <= now() and end_at > now()
   order by start_at desc limit 1;
  if found then
    if r.clear_on_start then
      delete from orders where true;
      delete from feedback where true;
      delete from help_requests where true;
      delete from room_access where true;
    end if;
    update config
       set staff_code = r.requested_code, locked = false, require_approval = r.require_approval,
           session_start = r.start_at, session_end = r.end_at, host_name = r.first_name
     where id = 1;
  end if;
  update room_requests set applied = true
   where status = 'approved' and applied = false and start_at <= now();
end $$;

grant execute on function check_staff_code(text) to anon;
grant execute on function check_main_code(text) to anon;
grant execute on function apply_due_sessions() to anon;

-- 3. De codes zijn niet meer uit te lezen via de app
revoke select on config from anon;
grant select (id, cafe_name, multi_drink_mode, ordering_open, locked, require_approval,
              session_start, session_end, host_name) on config to anon;

revoke select on room_requests from anon;
grant select (id, first_name, email, start_at, end_at, require_approval, device_id,
              status, applied, created_at) on room_requests to anon;

revoke select on app_settings from anon;
grant select (id) on app_settings to anon;
