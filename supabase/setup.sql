-- Combined Supabase setup script generated from the checked-in migrations.
-- Run once in the Supabase SQL Editor for a NEW/EMPTY project only.
-- Includes the demo-data seed migration; do not use that seed on production data.

-- ===== drizzle\migrations\0000_clinic_schema.sql =====

create type public.app_role as enum ('patient','doctor','receptionist');
create type public.appointment_status as enum ('booked','confirmed','checked_in','completed','cancelled');
create type public.queue_status as enum ('checkin_requested','waiting','in_consultation','completed','cancelled');
create type public.consultation_status as enum ('in_progress','completed');

create or replace function public.clinic_today() returns date language sql stable set search_path = public as $$ select (now() at time zone 'Asia/Kolkata')::date $$;
create or replace function public.clinic_now_time() returns time language sql stable set search_path = public as $$ select (now() at time zone 'Asia/Kolkata')::time $$;

create or replace function public.set_updated_at() returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end $$;

create table public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  primary key (user_id, role)
);

create table public.patients (
  patient_id int generated always as identity primary key,
  user_id uuid unique,
  name text not null check (char_length(name) between 2 and 100),
  email text check (email is null or email = lower(email)),
  phone text not null check (phone ~ '^\+?[0-9]{7,15}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index patients_email_uq on public.patients(email) where email is not null;

create table public.doctors (
  doctor_id int generated always as identity primary key,
  user_id uuid unique not null,
  name text not null,
  specialization text not null,
  slot_minutes smallint not null default 15 check (slot_minutes in (10,15,20,30)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.doctor_availability (
  availability_id int generated always as identity primary key,
  doctor_id int not null references public.doctors(doctor_id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  check (end_time > start_time),
  unique (doctor_id, day_of_week, start_time)
);

create table public.receptionists (
  receptionist_id int generated always as identity primary key,
  user_id uuid unique not null,
  name text not null,
  email text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.appointments (
  appointment_id int generated always as identity primary key,
  patient_id int not null references public.patients(patient_id) on delete cascade,
  doctor_id int not null references public.doctors(doctor_id) on delete cascade,
  appointment_date date not null,
  appointment_time time not null,
  status public.appointment_status not null default 'booked',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index appt_doctor_slot_uq on public.appointments(doctor_id, appointment_date, appointment_time) where status in ('booked','confirmed','checked_in');
create unique index appt_patient_slot_uq on public.appointments(patient_id, appointment_date, appointment_time) where status in ('booked','confirmed','checked_in');

create table public.queue_entries (
  queue_id int generated always as identity primary key,
  patient_id int not null references public.patients(patient_id) on delete cascade,
  doctor_id int not null references public.doctors(doctor_id) on delete cascade,
  appointment_id int references public.appointments(appointment_id) on delete cascade,
  queue_date date not null default public.clinic_today(),
  queue_position int check (queue_position is null or queue_position >= 1),
  status public.queue_status not null default 'checkin_requested',
  verified boolean not null default false,
  verified_by int references public.receptionists(receptionist_id),
  verified_at timestamptz,
  queued_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index queue_appt_uq on public.queue_entries(appointment_id) where status <> 'cancelled';

create table public.consultations (
  consultation_id int generated always as identity primary key,
  queue_id int unique not null references public.queue_entries(queue_id) on delete cascade,
  appointment_id int unique references public.appointments(appointment_id) on delete cascade,
  patient_id int not null references public.patients(patient_id) on delete cascade,
  doctor_id int not null references public.doctors(doctor_id) on delete cascade,
  consultation_date date not null default public.clinic_today(),
  status public.consultation_status not null default 'in_progress',
  notes text not null default '' check (char_length(notes) <= 5000),
  prescription text not null default '' check (char_length(prescription) <= 5000),
  verified_by int references public.receptionists(receptionist_id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index consult_active_uq on public.consultations(doctor_id) where status = 'in_progress';

create trigger t_upd before update on public.patients for each row execute function public.set_updated_at();
create trigger t_upd before update on public.doctors for each row execute function public.set_updated_at();
create trigger t_upd before update on public.receptionists for each row execute function public.set_updated_at();
create trigger t_upd before update on public.appointments for each row execute function public.set_updated_at();
create trigger t_upd before update on public.queue_entries for each row execute function public.set_updated_at();
create trigger t_upd before update on public.consultations for each row execute function public.set_updated_at();

-- Read-only grants: all writes go through security-definer RPCs.
grant select on public.user_roles, public.patients, public.doctors, public.doctor_availability, public.receptionists, public.appointments, public.queue_entries, public.consultations to authenticated;
grant all on public.user_roles, public.patients, public.doctors, public.doctor_availability, public.receptionists, public.appointments, public.queue_entries, public.consultations to service_role;

alter table public.user_roles enable row level security;
alter table public.patients enable row level security;
alter table public.doctors enable row level security;
alter table public.doctor_availability enable row level security;
alter table public.receptionists enable row level security;
alter table public.appointments enable row level security;
alter table public.queue_entries enable row level security;
alter table public.consultations enable row level security;

-- helpers
create or replace function public.has_role(_uid uuid, _role public.app_role) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = _uid and role = _role) $$;
create or replace function public.current_patient_id() returns int language sql stable security definer set search_path = public as $$
  select patient_id from public.patients where user_id = auth.uid() $$;
create or replace function public.current_doctor_id() returns int language sql stable security definer set search_path = public as $$
  select doctor_id from public.doctors where user_id = auth.uid() $$;
create or replace function public.current_receptionist_id() returns int language sql stable security definer set search_path = public as $$
  select receptionist_id from public.receptionists where user_id = auth.uid() $$;

create or replace function public.recalculate_queue(p_doctor_id int, p_date date) returns void language plpgsql security definer set search_path = public as $$
begin
  update public.queue_entries q set queue_position = null
   where q.doctor_id = p_doctor_id and q.queue_date = p_date and q.status <> 'waiting' and q.queue_position is not null;
  update public.queue_entries q set queue_position = r.rn
    from (select queue_id, row_number() over (order by queued_at, queue_id) rn from public.queue_entries
          where doctor_id = p_doctor_id and queue_date = p_date and status = 'waiting') r
   where q.queue_id = r.queue_id and q.queue_position is distinct from r.rn;
end $$;
revoke all on function public.recalculate_queue(int, date) from public, anon, authenticated;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text; v_phone text;
begin
  if new.raw_app_meta_data->>'staff' is not null then return new; end if;
  v_name := trim(coalesce(new.raw_user_meta_data->>'name',''));
  v_phone := regexp_replace(coalesce(new.raw_user_meta_data->>'phone',''), '[\s-]', '', 'g');
  if char_length(v_name) < 2 or char_length(v_name) > 100 then raise exception 'INVALID_NAME: Name must be 2-100 characters'; end if;
  if v_phone !~ '^\+?[0-9]{7,15}$' then raise exception 'INVALID_PHONE: Phone number is invalid'; end if;
  insert into public.patients(user_id, name, email, phone) values (new.id, v_name, lower(new.email), v_phone);
  insert into public.user_roles(user_id, role) values (new.id, 'patient') on conflict do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- RLS (select only)
create policy "own roles" on public.user_roles for select to authenticated using (user_id = auth.uid());
create policy "patients read" on public.patients for select to authenticated using (
  user_id = auth.uid()
  or public.has_role(auth.uid(),'receptionist')
  or (public.current_doctor_id() is not null and (
     exists (select 1 from public.appointments a where a.patient_id = patients.patient_id and a.doctor_id = public.current_doctor_id())
     or exists (select 1 from public.queue_entries q where q.patient_id = patients.patient_id and q.doctor_id = public.current_doctor_id())
     or exists (select 1 from public.consultations c where c.patient_id = patients.patient_id and c.doctor_id = public.current_doctor_id()))));
create policy "doctors read" on public.doctors for select to authenticated using (true);
create policy "availability read" on public.doctor_availability for select to authenticated using (true);
create policy "receptionist own" on public.receptionists for select to authenticated using (user_id = auth.uid());
create policy "appointments read" on public.appointments for select to authenticated using (
  patient_id = public.current_patient_id() or doctor_id = public.current_doctor_id() or public.has_role(auth.uid(),'receptionist'));
create policy "queue read" on public.queue_entries for select to authenticated using (
  patient_id = public.current_patient_id() or doctor_id = public.current_doctor_id() or public.has_role(auth.uid(),'receptionist'));
create policy "consultations read" on public.consultations for select to authenticated using (
  (patient_id = public.current_patient_id() and verified_at is not null) or doctor_id = public.current_doctor_id() or public.has_role(auth.uid(),'receptionist'));

alter publication supabase_realtime add table public.appointments, public.queue_entries, public.consultations;



-- ===== drizzle\migrations\0001_clinic_rpcs.sql =====

create or replace function public.get_available_slots(p_doctor_id int, p_date date)
returns table(slot_time time, is_available boolean) language plpgsql stable security definer set search_path = public as $$
declare v_slot int; w record; t time;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED: Please log in'; end if;
  if p_date < clinic_today() or p_date > clinic_today() + 30 then raise exception 'DATE_OUT_OF_RANGE: Date must be within the next 30 days'; end if;
  select slot_minutes into v_slot from doctors where doctor_id = p_doctor_id;
  if v_slot is null then raise exception 'NOT_FOUND: Doctor not found'; end if;
  for w in select start_time, end_time from doctor_availability where doctor_id = p_doctor_id and day_of_week = extract(dow from p_date)::int order by start_time loop
    t := w.start_time;
    while t + make_interval(mins => v_slot) <= w.end_time and t >= w.start_time loop
      slot_time := t;
      is_available := not exists (select 1 from appointments a where a.doctor_id = p_doctor_id and a.appointment_date = p_date and a.appointment_time = t and a.status in ('booked','confirmed','checked_in'))
        and not (p_date = clinic_today() and t <= clinic_now_time());
      return next;
      t := t + make_interval(mins => v_slot);
    end loop;
  end loop;
end $$;

create or replace function public.book_appointment(p_doctor_id int, p_date date, p_time time)
returns int language plpgsql security definer set search_path = public as $$
declare v_pid int := current_patient_id(); v_id int; v_ok boolean;
begin
  if v_pid is null or not has_role(auth.uid(),'patient') then raise exception 'FORBIDDEN: Patients only'; end if;
  if p_date < clinic_today() or p_date > clinic_today() + 30 then raise exception 'DATE_OUT_OF_RANGE: Date must be within the next 30 days'; end if;
  select s.is_available into v_ok from get_available_slots(p_doctor_id, p_date) s where s.slot_time = p_time;
  if v_ok is null then raise exception 'SLOT_INVALID: That time is not a valid slot'; end if;
  if not v_ok then raise exception 'SLOT_TAKEN: That slot is no longer available'; end if;
  if exists (select 1 from appointments where patient_id = v_pid and appointment_date = p_date and appointment_time = p_time and status in ('booked','confirmed','checked_in')) then
    raise exception 'PATIENT_CONFLICT: You already have an appointment at this time'; end if;
  begin
    insert into appointments(patient_id, doctor_id, appointment_date, appointment_time, status) values (v_pid, p_doctor_id, p_date, p_time, 'booked') returning appointment_id into v_id;
  exception when unique_violation then raise exception 'SLOT_TAKEN: That slot is no longer available'; end;
  update appointments set status = 'confirmed' where appointment_id = v_id;
  return v_id;
end $$;

create or replace function public.cancel_appointment(p_appointment_id int) returns void language plpgsql security definer set search_path = public as $$
declare a record;
begin
  select * into a from appointments where appointment_id = p_appointment_id and patient_id = current_patient_id();
  if a is null then raise exception 'NOT_FOUND: Appointment not found'; end if;
  if a.status not in ('booked','confirmed') then raise exception 'INVALID_TRANSITION: This appointment can no longer be cancelled'; end if;
  update appointments set status = 'cancelled' where appointment_id = p_appointment_id;
end $$;

create or replace function public._check_in(p_appointment_id int) returns int language plpgsql security definer set search_path = public as $$
declare a record; v_q int;
begin
  select * into a from appointments where appointment_id = p_appointment_id for update;
  if a is null then raise exception 'NOT_FOUND: Appointment not found'; end if;
  if a.status <> 'confirmed' then raise exception 'INVALID_TRANSITION: Only confirmed appointments can be checked in'; end if;
  if a.appointment_date <> clinic_today() then raise exception 'NOT_TODAY: Check-in is only possible on the appointment day'; end if;
  if exists (select 1 from queue_entries where appointment_id = p_appointment_id and status <> 'cancelled') then raise exception 'QUEUE_DUPLICATE: Already checked in'; end if;
  insert into queue_entries(patient_id, doctor_id, appointment_id, queue_date, status) values (a.patient_id, a.doctor_id, a.appointment_id, clinic_today(), 'checkin_requested') returning queue_id into v_q;
  update appointments set status = 'checked_in' where appointment_id = p_appointment_id;
  return v_q;
end $$;
revoke all on function public._check_in(int) from public, anon, authenticated;

create or replace function public.request_check_in(p_appointment_id int) returns int language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from appointments where appointment_id = p_appointment_id and patient_id = current_patient_id()) then raise exception 'NOT_FOUND: Appointment not found'; end if;
  return _check_in(p_appointment_id);
end $$;

create or replace function public.receptionist_check_in_patient(p_appointment_id int) returns int language plpgsql security definer set search_path = public as $$
begin
  if current_receptionist_id() is null then raise exception 'FORBIDDEN: Receptionists only'; end if;
  return _check_in(p_appointment_id);
end $$;

create or replace function public.verify_and_add_to_queue(p_queue_id int) returns int language plpgsql security definer set search_path = public as $$
declare v_r int := current_receptionist_id(); q record; v_pos int;
begin
  if v_r is null then raise exception 'FORBIDDEN: Receptionists only'; end if;
  select * into q from queue_entries where queue_id = p_queue_id for update;
  if q is null then raise exception 'NOT_FOUND: Queue entry not found'; end if;
  if q.status <> 'checkin_requested' then raise exception 'INVALID_TRANSITION: Entry is not awaiting verification'; end if;
  update queue_entries set verified = true, verified_by = v_r, verified_at = now(), status = 'waiting', queued_at = now() where queue_id = p_queue_id;
  perform recalculate_queue(q.doctor_id, q.queue_date);
  select queue_position into v_pos from queue_entries where queue_id = p_queue_id;
  return v_pos;
end $$;

create or replace function public.register_walk_in_patient(p_name text, p_phone text, p_email text, p_doctor_id int)
returns table(queue_id int, queue_position int) language plpgsql security definer set search_path = public as $$
declare v_r int := current_receptionist_id(); v_pid int; v_q int; v_name text := trim(p_name);
  v_phone text := regexp_replace(coalesce(p_phone,''), '[\s-]', '', 'g'); v_email text := nullif(lower(trim(coalesce(p_email,''))), '');
begin
  if v_r is null then raise exception 'FORBIDDEN: Receptionists only'; end if;
  if char_length(v_name) < 2 or char_length(v_name) > 100 then raise exception 'INVALID_NAME: Name must be 2-100 characters'; end if;
  if v_phone !~ '^\+?[0-9]{7,15}$' then raise exception 'INVALID_PHONE: Phone number is invalid'; end if;
  if not exists (select 1 from doctors where doctor_id = p_doctor_id) then raise exception 'NOT_FOUND: Doctor not found'; end if;
  if v_email is not null then select patient_id into v_pid from patients where email = v_email; end if;
  if v_pid is null then select patient_id into v_pid from patients where phone = v_phone and lower(name) = lower(v_name) limit 1; end if;
  if v_pid is null then insert into patients(name, email, phone) values (v_name, v_email, v_phone) returning patient_id into v_pid; end if;
  if exists (select 1 from queue_entries e where e.patient_id = v_pid and e.queue_date = clinic_today() and e.status in ('checkin_requested','waiting','in_consultation')) then
    raise exception 'QUEUE_DUPLICATE: This patient is already in today''s queue'; end if;
  insert into queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (v_pid, p_doctor_id, null, clinic_today(), 'waiting', true, v_r, now(), now()) returning queue_entries.queue_id into v_q;
  perform recalculate_queue(p_doctor_id, clinic_today());
  return query select e.queue_id, e.queue_position from queue_entries e where e.queue_id = v_q;
end $$;

create or replace function public.update_queue_status(p_queue_id int, p_status public.queue_status) returns void language plpgsql security definer set search_path = public as $$
declare q record; c record;
begin
  if current_receptionist_id() is null then raise exception 'FORBIDDEN: Receptionists only'; end if;
  select * into q from queue_entries where queue_id = p_queue_id for update;
  if q is null then raise exception 'NOT_FOUND: Queue entry not found'; end if;
  if p_status = 'cancelled' and q.status in ('checkin_requested','waiting') then
    update queue_entries set status = 'cancelled' where queue_id = p_queue_id;
    if q.appointment_id is not null then update appointments set status = 'confirmed' where appointment_id = q.appointment_id; end if;
  elsif p_status = 'completed' and q.status = 'in_consultation' then
    select * into c from consultations where queue_id = p_queue_id;
    if c is null or c.status <> 'completed' or c.verified_at is null then raise exception 'INVALID_TRANSITION: Consultation must be completed and verified first'; end if;
    update queue_entries set status = 'completed' where queue_id = p_queue_id;
    if q.appointment_id is not null then update appointments set status = 'completed' where appointment_id = q.appointment_id; end if;
  else
    raise exception 'INVALID_TRANSITION: That status change is not allowed';
  end if;
  perform recalculate_queue(q.doctor_id, q.queue_date);
end $$;

create or replace function public.start_consultation(p_queue_id int) returns int language plpgsql security definer set search_path = public as $$
declare v_d int := current_doctor_id(); q record; v_c int;
begin
  if v_d is null then raise exception 'FORBIDDEN: Doctors only'; end if;
  select * into q from queue_entries where queue_id = p_queue_id and doctor_id = v_d for update;
  if q is null then raise exception 'NOT_FOUND: Queue entry not found'; end if;
  if q.status <> 'waiting' then raise exception 'INVALID_TRANSITION: Patient is not waiting'; end if;
  if exists (select 1 from consultations where doctor_id = v_d and status = 'in_progress') then raise exception 'CONSULTATION_ACTIVE: Finish your current consultation first'; end if;
  insert into consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status) values (q.queue_id, q.appointment_id, q.patient_id, v_d, clinic_today(), 'in_progress') returning consultation_id into v_c;
  update queue_entries set status = 'in_consultation' where queue_id = p_queue_id;
  perform recalculate_queue(v_d, q.queue_date);
  return v_c;
end $$;

create or replace function public.update_consultation_status(p_consultation_id int, p_status public.consultation_status) returns void language plpgsql security definer set search_path = public as $$
declare c record;
begin
  select * into c from consultations where consultation_id = p_consultation_id and doctor_id = current_doctor_id() for update;
  if c is null then raise exception 'NOT_FOUND: Consultation not found'; end if;
  if not (c.status = 'in_progress' and p_status = 'completed') then raise exception 'INVALID_TRANSITION: That status change is not allowed'; end if;
  update consultations set status = 'completed' where consultation_id = p_consultation_id;
end $$;

create or replace function public._editable_consultation(p_consultation_id int, p_text text) returns void language plpgsql security definer set search_path = public as $$
declare c record;
begin
  select * into c from consultations where consultation_id = p_consultation_id and doctor_id = current_doctor_id();
  if c is null then raise exception 'NOT_FOUND: Consultation not found'; end if;
  if c.verified_at is not null then raise exception 'LOCKED: Consultation is verified and locked'; end if;
  if char_length(coalesce(p_text,'')) > 5000 then raise exception 'TOO_LONG: Maximum 5000 characters'; end if;
end $$;
revoke all on function public._editable_consultation(int, text) from public, anon, authenticated;

create or replace function public.save_consultation_notes(p_consultation_id int, p_notes text) returns void language plpgsql security definer set search_path = public as $$
begin perform _editable_consultation(p_consultation_id, p_notes); update consultations set notes = coalesce(p_notes,'') where consultation_id = p_consultation_id; end $$;
create or replace function public.save_prescription(p_consultation_id int, p_prescription text) returns void language plpgsql security definer set search_path = public as $$
begin perform _editable_consultation(p_consultation_id, p_prescription); update consultations set prescription = coalesce(p_prescription,'') where consultation_id = p_consultation_id; end $$;

create or replace function public.verify_consultation_status(p_consultation_id int) returns void language plpgsql security definer set search_path = public as $$
declare v_r int := current_receptionist_id(); c record;
begin
  if v_r is null then raise exception 'FORBIDDEN: Receptionists only'; end if;
  select * into c from consultations where consultation_id = p_consultation_id for update;
  if c is null then raise exception 'NOT_FOUND: Consultation not found'; end if;
  if c.status <> 'completed' or c.verified_at is not null then raise exception 'INVALID_TRANSITION: Consultation must be completed and not yet verified'; end if;
  update consultations set verified_by = v_r, verified_at = now() where consultation_id = p_consultation_id;
end $$;

do $$ declare f text; begin
  foreach f in array array['get_available_slots(int,date)','book_appointment(int,date,time)','cancel_appointment(int)','request_check_in(int)','receptionist_check_in_patient(int)','verify_and_add_to_queue(int)','register_walk_in_patient(text,text,text,int)','update_queue_status(int,public.queue_status)','start_consultation(int)','update_consultation_status(int,public.consultation_status)','save_consultation_notes(int,text)','save_prescription(int,text)','verify_consultation_status(int)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;



-- ===== drizzle\migrations\0002_clinic_seed_demo_data.sql =====

-- Demo filler data. Idempotent: skips users/rows that already exist.
do $$
declare
  u record; v_id uuid; d1 int; d2 int; d3 int; r1 int; p_ananya int; p_vikram int; p_kabir int; p_meera int; p_walk int;
  today date := public.clinic_today(); q int; a int;
begin
  for u in select * from (values
    ('11111111-1111-1111-1111-000000000001'::uuid,'aarav.mehta@example.com','Dr. Aarav Mehta',true,null::text),
    ('11111111-1111-1111-1111-000000000002'::uuid,'neha.kapoor@example.com','Dr. Neha Kapoor',true,null),
    ('11111111-1111-1111-1111-000000000003'::uuid,'rohan.iyer@example.com','Dr. Rohan Iyer',true,null),
    ('11111111-1111-1111-1111-000000000004'::uuid,'priya.sharma@example.com','Priya Sharma',true,null),
    ('22222222-2222-2222-2222-000000000001'::uuid,'ananya.rao@example.com','Ananya Rao',false,'+919810000001'),
    ('22222222-2222-2222-2222-000000000002'::uuid,'vikram.singh@example.com','Vikram Singh',false,'+919810000002'),
    ('22222222-2222-2222-2222-000000000003'::uuid,'kabir.das@example.com','Kabir Das',false,'+919810000003'),
    ('22222222-2222-2222-2222-000000000004'::uuid,'meera.nair@example.com','Meera Nair',false,'+919810000004')
  ) as t(id,email,name,staff,phone) loop
    if not exists (select 1 from auth.users where email = u.email) then
      insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change)
      values ('00000000-0000-0000-0000-000000000000',u.id,'authenticated','authenticated',u.email,extensions.crypt('Smaqms#2026',extensions.gen_salt('bf')),now(),
        case when u.staff then jsonb_build_object('provider','email','providers',jsonb_build_array('email'),'staff',true) else jsonb_build_object('provider','email','providers',jsonb_build_array('email')) end,
        case when u.staff then jsonb_build_object('name',u.name) else jsonb_build_object('name',u.name,'phone',u.phone) end,
        now(),now(),'','','','');
      insert into auth.identities(id,user_id,provider_id,identity_data,provider,last_sign_in_at,created_at,updated_at)
      values (gen_random_uuid(),u.id,u.id::text,jsonb_build_object('sub',u.id::text,'email',u.email,'email_verified',true),'email',now(),now(),now());
    end if;
  end loop;

  insert into public.doctors(user_id,name,specialization) values
    ('11111111-1111-1111-1111-000000000001','Dr. Aarav Mehta','General Physician'),
    ('11111111-1111-1111-1111-000000000002','Dr. Neha Kapoor','Pediatrician'),
    ('11111111-1111-1111-1111-000000000003','Dr. Rohan Iyer','Cardiologist') on conflict do nothing;
  insert into public.receptionists(user_id,name,email) values ('11111111-1111-1111-1111-000000000004','Priya Sharma','priya.sharma@example.com') on conflict do nothing;
  insert into public.user_roles(user_id,role) values
    ('11111111-1111-1111-1111-000000000001','doctor'),('11111111-1111-1111-1111-000000000002','doctor'),
    ('11111111-1111-1111-1111-000000000003','doctor'),('11111111-1111-1111-1111-000000000004','receptionist') on conflict do nothing;

  insert into public.doctor_availability(doctor_id,day_of_week,start_time,end_time)
    select d.doctor_id, dow, s, e from public.doctors d, generate_series(1,6) dow, (values ('09:00'::time,'13:00'::time),('14:00','17:00')) w(s,e)
    on conflict do nothing;

  select doctor_id into d1 from public.doctors where user_id = '11111111-1111-1111-1111-000000000001';
  select doctor_id into d2 from public.doctors where user_id = '11111111-1111-1111-1111-000000000002';
  select doctor_id into d3 from public.doctors where user_id = '11111111-1111-1111-1111-000000000003';
  select receptionist_id into r1 from public.receptionists limit 1;
  select patient_id into p_ananya from public.patients where user_id = '22222222-2222-2222-2222-000000000001';
  select patient_id into p_vikram from public.patients where user_id = '22222222-2222-2222-2222-000000000002';
  select patient_id into p_kabir from public.patients where user_id = '22222222-2222-2222-2222-000000000003';
  select patient_id into p_meera from public.patients where user_id = '22222222-2222-2222-2222-000000000004';

  if exists (select 1 from public.appointments) then return; end if;

  -- Ananya: confirmed today (ready to check in) + future booking
  insert into public.appointments(patient_id,doctor_id,appointment_date,appointment_time,status) values
    (p_ananya,d1,today,'16:45','confirmed'),(p_ananya,d2,today+3,'10:00','confirmed'),(p_ananya,d3,today-10,'11:00','cancelled');
  -- Meera: checked in, awaiting receptionist verification
  insert into public.appointments(patient_id,doctor_id,appointment_date,appointment_time,status) values (p_meera,d2,today,'09:30','checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id,doctor_id,appointment_id,queue_date,status) values (p_meera,d2,a,today,'checkin_requested');
  -- Vikram: waiting in Dr. Mehta's queue
  insert into public.appointments(patient_id,doctor_id,appointment_date,appointment_time,status) values (p_vikram,d1,today,'09:15','checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id,doctor_id,appointment_id,queue_date,status,verified,verified_by,verified_at,queued_at)
    values (p_vikram,d1,a,today,'waiting',true,r1,now()-interval '20 minutes',now()-interval '20 minutes');
  -- Walk-in patient waiting for Dr. Mehta
  insert into public.patients(name,phone) values ('Suresh Kumar','+919820000010') returning patient_id into p_walk;
  insert into public.queue_entries(patient_id,doctor_id,queue_date,status,verified,verified_by,verified_at,queued_at)
    values (p_walk,d1,today,'waiting',true,r1,now()-interval '10 minutes',now()-interval '10 minutes');
  -- Kabir: past completed + verified consultation
  insert into public.appointments(patient_id,doctor_id,appointment_date,appointment_time,status) values (p_kabir,d3,today-2,'11:30','completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id,doctor_id,appointment_id,queue_date,status,verified,verified_by,verified_at,queued_at)
    values (p_kabir,d3,a,today-2,'completed',true,r1,now()-interval '2 days',now()-interval '2 days') returning queue_id into q;
  insert into public.consultations(queue_id,appointment_id,patient_id,doctor_id,consultation_date,status,notes,prescription,verified_by,verified_at)
    values (q,a,p_kabir,d3,today-2,'completed','Mild hypertension. BP 142/90. Advised low-salt diet and daily walks.','Amlodipine 5mg - once daily after breakfast, 30 days.',r1,now()-interval '2 days');
  -- Kabir: upcoming
  insert into public.appointments(patient_id,doctor_id,appointment_date,appointment_time,status) values (p_kabir,d3,today+7,'14:30','confirmed');

  perform public.recalculate_queue(d1, today);
  perform public.recalculate_queue(d2, today);
end $$;



-- ===== drizzle\migrations\0003_receptionist_start_consultation.sql =====
create or replace function public.start_consultation(p_queue_id int) returns int language plpgsql security definer set search_path = public as $$
declare v_d int := current_doctor_id(); v_r int := current_receptionist_id(); q record; v_c int;
begin
  if v_d is null and v_r is null then raise exception 'FORBIDDEN: Doctors and receptionists only'; end if;
  select * into q from queue_entries where queue_id = p_queue_id for update;
  if q is null then raise exception 'NOT_FOUND: Queue entry not found'; end if;
  if v_d is not null and q.doctor_id <> v_d then raise exception 'NOT_FOUND: Queue entry not found'; end if;
  if q.status <> 'waiting' then raise exception 'INVALID_TRANSITION: Patient is not waiting'; end if;
  if exists (select 1 from consultations where doctor_id = q.doctor_id and status = 'in_progress') then raise exception 'CONSULTATION_ACTIVE: Finish the current consultation first'; end if;
  insert into consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status) values (q.queue_id, q.appointment_id, q.patient_id, q.doctor_id, clinic_today(), 'in_progress') returning consultation_id into v_c;
  update queue_entries set status = 'in_consultation' where queue_id = p_queue_id;
  perform recalculate_queue(q.doctor_id, q.queue_date);
  return v_c;
end $$;

revoke all on function public.start_consultation(int) from public, anon;
grant execute on function public.start_consultation(int) to authenticated;


-- ===== drizzle\migrations\0004_keep_position_while_in_consultation.sql =====
create or replace function public.recalculate_queue(p_doctor_id int, p_date date) returns void language plpgsql security definer set search_path = public as $$
begin
  update public.queue_entries q set queue_position = null
   where q.doctor_id = p_doctor_id and q.queue_date = p_date and q.status not in ('waiting','in_consultation') and q.queue_position is not null;
  update public.queue_entries q set queue_position = r.rn
    from (select queue_id, row_number() over (order by case when status = 'in_consultation' then 0 else 1 end, queued_at, queue_id) rn from public.queue_entries
          where doctor_id = p_doctor_id and queue_date = p_date and status in ('waiting','in_consultation')) r
   where q.queue_id = r.queue_id and q.queue_position is distinct from r.rn;
end $$;

revoke all on function public.recalculate_queue(int, date) from public, anon, authenticated;

-- renumber today's queues so existing rows match the new rule
select public.recalculate_queue(doctor_id, queue_date) from (select distinct doctor_id, queue_date from public.queue_entries) s;


-- ===== drizzle\migrations\0005_public_queue_board.sql =====
create or replace function public.public_queue_board()
returns table (
  doctor_id int,
  doctor_name text,
  specialization text,
  now_serving int,
  waiting_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    d.doctor_id,
    d.name,
    d.specialization,
    (
      select q.queue_position
      from public.queue_entries q
      where q.doctor_id = d.doctor_id
        and q.queue_date = public.clinic_today()
        and q.status = 'in_consultation'
      order by q.queued_at nulls last, q.queue_id
      limit 1
    ) as now_serving,
    (
      select count(*)
      from public.queue_entries q
      where q.doctor_id = d.doctor_id
        and q.queue_date = public.clinic_today()
        and q.status = 'waiting'
    ) as waiting_count
  from public.doctors d
  order by d.name;
$$;

revoke all on function public.public_queue_board() from public;
grant execute on function public.public_queue_board() to anon, authenticated;
