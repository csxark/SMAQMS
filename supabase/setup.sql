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


-- ===== drizzle\migrations\0006_reset_and_seed_comprehensive_data.sql =====
-- Migration: Comprehensive Seed Data (10 Doctors, 3 Receptionists, 60 Patients with Queues, Appointments, Consultations)
-- First removes all existing data from all tables (leaving structures intact) and reseeds complete records.

-- 1. Wipe all data from public tables and reset sequences
truncate table
  public.consultations,
  public.queue_entries,
  public.appointments,
  public.doctor_availability,
  public.doctors,
  public.receptionists,
  public.patients,
  public.user_roles
restart identity cascade;

-- 2. Clear existing auth identities and users
delete from auth.identities;
delete from auth.users;

-- 3. Seed staff, patients, availability, appointments, queues, and consultations
do $$
declare
  u record;
  today date := public.clinic_today();
  r1 int; r2 int; r3 int;
  d_id int;
  p_id int;
  p_walk1 int; p_walk2 int; p_walk3 int; p_walk4 int; p_walk5 int;
  a int;
  q int;
  doc_rec record;
begin
  -- 3.1 Insert Auth Users & Identities for Staff (Doctors + Receptionists)
  for u in select * from (values
    ('11111111-1111-1111-1111-000000000001'::uuid, 'aarav.mehta@example.com', 'Dr. Aarav Mehta', true, null::text),
    ('11111111-1111-1111-1111-000000000002'::uuid, 'neha.kapoor@example.com', 'Dr. Neha Kapoor', true, null::text),
    ('11111111-1111-1111-1111-000000000003'::uuid, 'rohan.iyer@example.com', 'Dr. Rohan Iyer', true, null::text),
    ('11111111-1111-1111-1111-000000000004'::uuid, 'shalini.verma@example.com', 'Dr. Shalini Verma', true, null::text),
    ('11111111-1111-1111-1111-000000000005'::uuid, 'rajesh.kulkarni@example.com', 'Dr. Rajesh Kulkarni', true, null::text),
    ('11111111-1111-1111-1111-000000000006'::uuid, 'ananya.sen@example.com', 'Dr. Ananya Sen', true, null::text),
    ('11111111-1111-1111-1111-000000000007'::uuid, 'vikram.joshi@example.com', 'Dr. Vikramaditya Joshi', true, null::text),
    ('11111111-1111-1111-1111-000000000008'::uuid, 'pooja.deshmukh@example.com', 'Dr. Pooja Deshmukh', true, null::text),
    ('11111111-1111-1111-1111-000000000009'::uuid, 'siddharth.nambiar@example.com', 'Dr. Siddharth Nambiar', true, null::text),
    ('11111111-1111-1111-1111-000000000010'::uuid, 'tanvi.bhatia@example.com', 'Dr. Tanvi Bhatia', true, null::text),
    ('11111111-1111-1111-2222-000000000001'::uuid, 'priya.sharma@example.com', 'Priya Sharma', true, null::text),
    ('11111111-1111-1111-2222-000000000002'::uuid, 'amit.trivedi@example.com', 'Amit Trivedi', true, null::text),
    ('11111111-1111-1111-2222-000000000003'::uuid, 'sunita.rao@example.com', 'Sunita Rao', true, null::text)
  ) as t(id, email, name, staff, phone) loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
      extensions.crypt('Smaqms#2026', extensions.gen_salt('bf')), now(),
      jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'), 'staff', true),
      jsonb_build_object('name', u.name),
      now(), now(), '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), u.id, u.id::text,
      jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
      'email', now(), now(), now()
    );
  end loop;

  -- 3.2 Insert Doctors
  insert into public.doctors(user_id, name, specialization, slot_minutes) values
    ('11111111-1111-1111-1111-000000000001', 'Dr. Aarav Mehta', 'General Physician', 15),
    ('11111111-1111-1111-1111-000000000002', 'Dr. Neha Kapoor', 'Pediatrician', 15),
    ('11111111-1111-1111-1111-000000000003', 'Dr. Rohan Iyer', 'Cardiologist', 20),
    ('11111111-1111-1111-1111-000000000004', 'Dr. Shalini Verma', 'Dermatologist', 15),
    ('11111111-1111-1111-1111-000000000005', 'Dr. Rajesh Kulkarni', 'Orthopedic Surgeon', 20),
    ('11111111-1111-1111-1111-000000000006', 'Dr. Ananya Sen', 'Neurologist', 30),
    ('11111111-1111-1111-1111-000000000007', 'Dr. Vikramaditya Joshi', 'ENT Specialist', 15),
    ('11111111-1111-1111-1111-000000000008', 'Dr. Pooja Deshmukh', 'Gynecologist', 20),
    ('11111111-1111-1111-1111-000000000009', 'Dr. Siddharth Nambiar', 'Ophthalmologist', 15),
    ('11111111-1111-1111-1111-000000000010', 'Dr. Tanvi Bhatia', 'Pulmonologist', 20);

  -- 3.3 Insert Receptionists
  insert into public.receptionists(user_id, name, email) values
    ('11111111-1111-1111-2222-000000000001', 'Priya Sharma', 'priya.sharma@example.com'),
    ('11111111-1111-1111-2222-000000000002', 'Amit Trivedi', 'amit.trivedi@example.com'),
    ('11111111-1111-1111-2222-000000000003', 'Sunita Rao', 'sunita.rao@example.com');

  -- 3.4 Insert Staff User Roles
  insert into public.user_roles(user_id, role) values
    ('11111111-1111-1111-1111-000000000001', 'doctor'),
    ('11111111-1111-1111-1111-000000000002', 'doctor'),
    ('11111111-1111-1111-1111-000000000003', 'doctor'),
    ('11111111-1111-1111-1111-000000000004', 'doctor'),
    ('11111111-1111-1111-1111-000000000005', 'doctor'),
    ('11111111-1111-1111-1111-000000000006', 'doctor'),
    ('11111111-1111-1111-1111-000000000007', 'doctor'),
    ('11111111-1111-1111-1111-000000000008', 'doctor'),
    ('11111111-1111-1111-1111-000000000009', 'doctor'),
    ('11111111-1111-1111-1111-000000000010', 'doctor'),
    ('11111111-1111-1111-2222-000000000001', 'receptionist'),
    ('11111111-1111-1111-2222-000000000002', 'receptionist'),
    ('11111111-1111-1111-2222-000000000003', 'receptionist');

  -- 3.5 Insert Doctor Availability (Mon-Sat, Morning 09:00-13:00 and Afternoon 14:00-18:00)
  insert into public.doctor_availability(doctor_id, day_of_week, start_time, end_time)
  select d.doctor_id, dow, s, e
  from public.doctors d
  cross join generate_series(1, 6) dow
  cross join (values ('09:00'::time, '13:00'::time), ('14:00'::time, '18:00'::time)) w(s, e);

  -- 3.6 Insert 60 Patient Auth Users (Trigger on_auth_user_created automatically populates public.patients & user_roles)
  for u in select * from (values
    ('22222222-2222-2222-2222-000000000001'::uuid, 'ananya.rao@example.com', 'Ananya Rao', false, '+919810000001'),
    ('22222222-2222-2222-2222-000000000002'::uuid, 'vikram.singh@example.com', 'Vikram Singh', false, '+919810000002'),
    ('22222222-2222-2222-2222-000000000003'::uuid, 'kabir.das@example.com', 'Kabir Das', false, '+919810000003'),
    ('22222222-2222-2222-2222-000000000004'::uuid, 'meera.nair@example.com', 'Meera Nair', false, '+919810000004'),
    ('22222222-2222-2222-2222-000000000005'::uuid, 'arjun.patel@example.com', 'Arjun Patel', false, '+919810000005'),
    ('22222222-2222-2222-2222-000000000006'::uuid, 'sneha.reddy@example.com', 'Sneha Reddy', false, '+919810000006'),
    ('22222222-2222-2222-2222-000000000007'::uuid, 'aarohi.gupta@example.com', 'Aarohi Gupta', false, '+919810000007'),
    ('22222222-2222-2222-2222-000000000008'::uuid, 'devansh.bose@example.com', 'Devansh Bose', false, '+919810000008'),
    ('22222222-2222-2222-2222-000000000009'::uuid, 'ishaan.malhotra@example.com', 'Ishaan Malhotra', false, '+919810000009'),
    ('22222222-2222-2222-2222-000000000010'::uuid, 'riya.sengupta@example.com', 'Riya Sengupta', false, '+919810000010'),
    ('22222222-2222-2222-2222-000000000011'::uuid, 'aditya.choudhury@example.com', 'Aditya Choudhury', false, '+919810000011'),
    ('22222222-2222-2222-2222-000000000012'::uuid, 'kavya.pillai@example.com', 'Kavya Pillai', false, '+919810000012'),
    ('22222222-2222-2222-2222-000000000013'::uuid, 'harish.venkatesh@example.com', 'Harish Venkatesh', false, '+919810000013'),
    ('22222222-2222-2222-2222-000000000014'::uuid, 'nalini.sundaram@example.com', 'Nalini Sundaram', false, '+919810000014'),
    ('22222222-2222-2222-2222-000000000015'::uuid, 'rahul.saxena@example.com', 'Rahul Saxena', false, '+919810000015'),
    ('22222222-2222-2222-2222-000000000016'::uuid, 'shilpa.agarwal@example.com', 'Shilpa Agarwal', false, '+919810000016'),
    ('22222222-2222-2222-2222-000000000017'::uuid, 'manjunath.hegde@example.com', 'Manjunath Hegde', false, '+919810000017'),
    ('22222222-2222-2222-2222-000000000018'::uuid, 'divya.menon@example.com', 'Divya Menon', false, '+919810000018'),
    ('22222222-2222-2222-2222-000000000019'::uuid, 'rohit.khanna@example.com', 'Rohit Khanna', false, '+919810000019'),
    ('22222222-2222-2222-2222-000000000020'::uuid, 'kriti.sanon@example.com', 'Kriti Sanon', false, '+919810000020'),
    ('22222222-2222-2222-2222-000000000021'::uuid, 'varun.dhawan@example.com', 'Varun Dhawan', false, '+919810000021'),
    ('22222222-2222-2222-2222-000000000022'::uuid, 'tanvi.deshmukh@example.com', 'Tanvi Deshmukh', false, '+919810000022'),
    ('22222222-2222-2222-2222-000000000023'::uuid, 'gaurav.bajaj@example.com', 'Gaurav Bajaj', false, '+919810000023'),
    ('22222222-2222-2222-2222-000000000024'::uuid, 'alok.tripathi@example.com', 'Alok Tripathi', false, '+919810000024'),
    ('22222222-2222-2222-2222-000000000025'::uuid, 'bhaskar.murthy@example.com', 'Bhaskar Murthy', false, '+919810000025'),
    ('22222222-2222-2222-2222-000000000026'::uuid, 'sunita.chatterjee@example.com', 'Sunita Chatterjee', false, '+919810000026'),
    ('22222222-2222-2222-2222-000000000027'::uuid, 'pradeep.kadam@example.com', 'Pradeep Kadam', false, '+919810000027'),
    ('22222222-2222-2222-2222-000000000028'::uuid, 'leela.krishnan@example.com', 'Leela Krishnan', false, '+919810000028'),
    ('22222222-2222-2222-2222-000000000029'::uuid, 'chetan.shrestha@example.com', 'Chetan Shrestha', false, '+919810000029'),
    ('22222222-2222-2222-2222-000000000030'::uuid, 'vandana.prabhu@example.com', 'Vandana Prabhu', false, '+919810000030'),
    ('22222222-2222-2222-2222-000000000031'::uuid, 'deepak.varma@example.com', 'Deepak Varma', false, '+919810000031'),
    ('22222222-2222-2222-2222-000000000032'::uuid, 'maya.namboodiri@example.com', 'Maya Namboodiri', false, '+919810000032'),
    ('22222222-2222-2222-2222-000000000033'::uuid, 'ashok.ganguly@example.com', 'Ashok Ganguly', false, '+919810000033'),
    ('22222222-2222-2222-2222-000000000034'::uuid, 'jyoti.pandey@example.com', 'Jyoti Pandey', false, '+919810000034'),
    ('22222222-2222-2222-2222-000000000035'::uuid, 'karthik.raman@example.com', 'Karthik Raman', false, '+919810000035'),
    ('22222222-2222-2222-2222-000000000036'::uuid, 'swati.deshpande@example.com', 'Swati Deshpande', false, '+919810000036'),
    ('22222222-2222-2222-2222-000000000037'::uuid, 'girish.mahajan@example.com', 'Girish Mahajan', false, '+919810000037'),
    ('22222222-2222-2222-2222-000000000038'::uuid, 'pallavi.gokhale@example.com', 'Pallavi Gokhale', false, '+919810000038'),
    ('22222222-2222-2222-2222-000000000039'::uuid, 'sumit.mathur@example.com', 'Sumit Mathur', false, '+919810000039'),
    ('22222222-2222-2222-2222-000000000040'::uuid, 'anjali.mishra@example.com', 'Anjali Mishra', false, '+919810000040'),
    ('22222222-2222-2222-2222-000000000041'::uuid, 'naveen.yadav@example.com', 'Naveen Yadav', false, '+919810000041'),
    ('22222222-2222-2222-2222-000000000042'::uuid, 'preeti.chadha@example.com', 'Preeti Chadha', false, '+919810000042'),
    ('22222222-2222-2222-2222-000000000043'::uuid, 'shweta.tiwari@example.com', 'Shweta Tiwari', false, '+919810000043'),
    ('22222222-2222-2222-2222-000000000044'::uuid, 'radhika.apte@example.com', 'Radhika Apte', false, '+919810000044'),
    ('22222222-2222-2222-2222-000000000045'::uuid, 'madhuri.bhat@example.com', 'Madhuri Bhat', false, '+919810000045'),
    ('22222222-2222-2222-2222-000000000046'::uuid, 'sandeep.kulkarni@example.com', 'Sandeep Kulkarni', false, '+919810000046'),
    ('22222222-2222-2222-2222-000000000047'::uuid, 'ritu.rawat@example.com', 'Ritu Rawat', false, '+919810000047'),
    ('22222222-2222-2222-2222-000000000048'::uuid, 'smita.patil@example.com', 'Smita Patil', false, '+919810000048'),
    ('22222222-2222-2222-2222-000000000049'::uuid, 'omkar.joshi@example.com', 'Omkar Joshi', false, '+919810000049'),
    ('22222222-2222-2222-2222-000000000050'::uuid, 'nandita.das@example.com', 'Nandita Das', false, '+919810000050'),
    ('22222222-2222-2222-2222-000000000051'::uuid, 'jagdish.chandra@example.com', 'Jagdish Chandra', false, '+919810000051'),
    ('22222222-2222-2222-2222-000000000052'::uuid, 'usha.uthup@example.com', 'Usha Uthup', false, '+919810000052'),
    ('22222222-2222-2222-2222-000000000053'::uuid, 'mahesh.bhatt@example.com', 'Mahesh Bhatt', false, '+919810000053'),
    ('22222222-2222-2222-2222-000000000054'::uuid, 'geeta.govinda@example.com', 'Geeta Govinda', false, '+919810000054'),
    ('22222222-2222-2222-2222-000000000055'::uuid, 'raghuram.rajan@example.com', 'Raghuram Rajan', false, '+919810000055'),
    ('22222222-2222-2222-2222-000000000056'::uuid, 'tara.sharma@example.com', 'Tara Sharma', false, '+919810000056'),
    ('22222222-2222-2222-2222-000000000057'::uuid, 'vinay.pathak@example.com', 'Vinay Pathak', false, '+919810000057'),
    ('22222222-2222-2222-2222-000000000058'::uuid, 'payal.ghosh@example.com', 'Payal Ghosh', false, '+919810000058'),
    ('22222222-2222-2222-2222-000000000059'::uuid, 'yashwant.sinha@example.com', 'Yashwant Sinha', false, '+919810000059'),
    ('22222222-2222-2222-2222-000000000060'::uuid, 'zarina.wahab@example.com', 'Zarina Wahab', false, '+919810000060')
  ) as t(id, email, name, staff, phone) loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
      extensions.crypt('Smaqms#2026', extensions.gen_salt('bf')), now(),
      jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
      jsonb_build_object('name', u.name, 'phone', u.phone),
      now(), now(), '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), u.id, u.id::text,
      jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
      'email', now(), now(), now()
    );
  end loop;

  -- 3.7 Insert Walk-in Patients (without auth users)
  insert into public.patients(name, phone) values ('Suresh Kumar', '+919820000001') returning patient_id into p_walk1;
  insert into public.patients(name, phone) values ('Lakshmi Narayanan', '+919820000002') returning patient_id into p_walk2;
  insert into public.patients(name, phone) values ('Ramesh Gupta', '+919820000003') returning patient_id into p_walk3;
  insert into public.patients(name, phone) values ('Fatima Sheikh', '+919820000004') returning patient_id into p_walk4;
  insert into public.patients(name, phone) values ('Balwinder Singh', '+919820000005') returning patient_id into p_walk5;

  -- Query receptionist IDs
  select receptionist_id into r1 from public.receptionists where email = 'priya.sharma@example.com';
  select receptionist_id into r2 from public.receptionists where email = 'amit.trivedi@example.com';
  select receptionist_id into r3 from public.receptionists where email = 'sunita.rao@example.com';

  -- 3.8 Appointments, Queues, and Consultation Records across 10 Doctors

  -- =========================================================================
  -- DOCTOR 1: Dr. Aarav Mehta (General Physician)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000001';

  -- Patient 1 (Ananya Rao): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000001';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      'Patient presented with 2-day history of acute watery diarrhea, nausea, low-grade fever (99.2 F), and generalized abdominal cramping. Vitals: BP 118/76 mmHg, HR 84 bpm, SpO2 98%. Abdomen soft, diffuse mild epigastric and periumbilical tenderness without guarding or rigidity.',
      '1. ORS Electrolyte Solution - Dissolve 1 packet in 1L boiled and cooled water, sip frequently (minimum 2L daily)
2. Tab Ondansetron 4mg - 1 tab 30 mins before meals SOS for nausea
3. Cap Bacillus clausii spores (Probiotic) - 1 capsule twice daily for 5 days
4. Bland BRAT diet (Banana, Rice, Applesauce, Toast). Avoid dairy, greasy, and spicy food. Review if fever > 101 F or blood in stools.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 2 (Vikram Singh): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000002';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      'Routine health check follow-up. Patient reports occasional morning occipital tension headaches. Vitals: BP 152/94 mmHg (confirmed sitting, bilateral arms), HR 76 bpm, BMI 28.2 kg/m2. Fasting lipid panel: Total Cholesterol 228 mg/dL, LDL 148 mg/dL, Triglycerides 190 mg/dL. ECG unremarkable.',
      '1. Tab Telmisartan 40mg + Amlodipine 5mg - 1 tablet once daily morning after breakfast (30 days)
2. Tab Atorvastatin 10mg - 1 tablet at bedtime (30 days)
3. Lifestyle: Low salt intake (< 2g/day), aerobic exercise (brisk walking 30 min 5 days/week), avoid processed fats. Recheck BP in 2 weeks and repeat lipid panel in 6 weeks.',
      r2, now() - interval '2 hours');

  -- Patient 3 (Kabir Das): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000003';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      'Complains of worsening lethargy, polyuria, and polydipsia over the past 3 weeks. Fasting blood sugar 188 mg/dL, Postprandial 264 mg/dL, HbA1c 8.6%. Urine routine shows microalbuminuria (ACR 45 mg/g). Peripheral pulses palpable, monofilament sensory exam intact.',
      '1. Tab Metformin 1000mg ER - 1 tablet twice daily with breakfast and dinner (30 days)
2. Tab Glimepiride 1mg - 1 tablet once daily before breakfast (30 days)
3. Strict diabetic diet plan: complex carbohydrates, high fiber, eliminate refined sugar and sodas.
4. Self-monitoring of blood glucose twice weekly. Medical nutrition therapy consult ordered.');

  -- Patient 4 (Meera Nair): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000004';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 5 (Arjun Patel): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000005';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 6 (Sneha Reddy): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000006';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- =========================================================================
  -- DOCTOR 2: Dr. Neha Kapoor (Pediatrician)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000002';

  -- Patient 7 (Aarohi Gupta): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000007';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      '4-year-old child brought in with intense right ear pain, crying, ear tugging, and fever of 101.4 F for 24 hours. Otoscopic exam: Right tympanic membrane markedly erythematous, bulging, with loss of light reflex. Left ear normal.',
      '1. Syp Amoxicillin-Potassium Clavulanate (228mg/5ml) - 5ml twice daily after meals for 7 days
2. Syp Paracetamol (250mg/5ml) - 5ml every 6 hours SOS for pain/fever
3. Syp Levocetirizine (2.5mg/5ml) - 2.5ml once daily at bedtime for 5 days
4. Keep ears strictly dry during bathing. Review in clinic after 5 days or immediately if ear discharge occurs.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 8 (Devansh Bose): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000008';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      '7-year-old child presenting with dry nocturnal coughing, wheezing, and dyspnea after viral illness. Auscultation reveals bilateral expiratory wheezes and prolonged expiration. SpO2 96% on room air, respiratory rate 26/min.',
      '1. Inhaler Levosalbutamol (50mcg) + Ipratropium (20mcg) via pediatric spacer - 2 puffs thrice daily for 5 days
2. Inhaler Budesonide (100mcg) via spacer - 2 puffs twice daily with mouth rinsing afterwards (ongoing)
3. Syp Prednisolone (15mg/5ml) - 5ml once daily in the morning after breakfast for 3 days
4. Environmental allergen avoidance: dust mites, dampness, cold air, pet dander.',
      r2, now() - interval '2 hours');

  -- Patient 9 (Ishaan Malhotra): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000009';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      'Child aged 5 years presenting with pallor, low appetite, and pica (eating ice/mud). Complete Blood Count: Hb 8.9 g/dL, MCV 66 fL, MCH 21 pg, Serum Ferritin 8 ng/mL (low). Stool for ova/cyst negative.',
      '1. Syp Ferrous Ascorbate (Iron 30mg + Folic acid 500mcg per 5ml) - 5ml once daily after dinner for 3 months
2. Syp Albendazole 400mg - Single dose deworming tonight
3. Dietary counseling: green leafy vegetables, dates, jaggery, lentils, pomegranate. Avoid giving milk with iron syrup.');

  -- Patient 10 (Riya Sengupta): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000010';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 11 (Aditya Choudhury): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000011';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 12 (Kavya Pillai): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000012';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- =========================================================================
  -- DOCTOR 3: Dr. Rohan Iyer (Cardiologist)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000003';

  -- Patient 13 (Harish Venkatesh): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000013';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      'Known ischemic heart disease patient with retrosternal chest tightness brought on by climbing two flights of stairs, relieved by 5 minutes rest. Resting ECG shows ST depression in leads II, III, aVF. 2D Echo: Normal LV systolic function, LVEF 55%, mild anterior hypokinesia.',
      '1. Tab Aspirin 75mg + Atorvastatin 20mg - 1 capsule daily after dinner (30 days)
2. Tab Metoprolol Succinate 50mg ER - 1 tablet once daily morning (30 days)
3. Tab Isosorbide Mononitrate 30mg SR - 1 tablet daily morning after food (30 days)
4. Tab Sorbitrate 5mg - 1 tablet sublingually immediately for acute anginal episodes. Proceed to ER if pain > 10 min.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 14 (Nalini Sundaram): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000014';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      'Presents with progressive exertional dyspnea (NYHA Class II to III), bilateral pitting pedal edema (+2), and orthopnea. Jugular venous pressure elevated to 4 cm above sternal angle. 2D Echo: Dilated LV, global hypokinesia, LVEF 36%. BNP 680 pg/mL.',
      '1. Tab Sacubitril / Valsartan 24/26mg - 1 tablet twice daily (titrate in 4 weeks)
2. Tab Furosemide 40mg - 1 tablet morning on empty stomach (30 days)
3. Tab Spironolactone 25mg - 1 tablet once daily (30 days)
4. Tab Empagliflozin 10mg - 1 tablet once daily with lunch (30 days)
5. Fluid restriction to 1.5L/day, daily morning weight recording, salt intake < 2g/day.',
      r2, now() - interval '2 hours');

  -- Patient 15 (Rahul Saxena): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000015';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      'Episodes of sudden palpitation, lightheadedness, and chest flutter lasting 30-45 minutes. 12-lead ECG demonstrates irregularly irregular rhythm, absent P waves, ventricular rate 132 bpm. CHA2DS2-VASc score = 3.',
      '1. Tab Apixaban 5mg - 1 tablet twice daily with or without food (30 days)
2. Tab Bisoprolol Fumarate 5mg - 1 tablet once daily morning (30 days)
3. Electrolyte panel ordered (Serum K+ and Mg2+). Cardiac electrophysiology follow-up in 3 weeks.
4. Avoid caffeine, alcohol, decongestants, and heavy physical strain.');

  -- Patient 16 (Shilpa Agarwal): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000016';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 17 (Manjunath Hegde): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000017';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 18 (Divya Menon): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000018';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- =========================================================================
  -- DOCTOR 4: Dr. Shalini Verma (Dermatologist)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000004';

  -- Patient 19 (Rohit Khanna): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000019';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      'Well-demarcated erythematous plaques with thick silvery-white mica-like scales on extensor surfaces of bilateral elbows, knees, and lumbosacral region. Auspitz sign positive. PASI score 8.4. Nail pitting present on thumbs.',
      '1. Ointment Clobetasol Propionate 0.05% + Salicylic Acid 6% - Apply thin film twice daily to plaques for 14 days
2. Cream Calcipotriol 0.005% - Apply once daily in the evening
3. Liquid Paraffin + White Soft Paraffin Emollient - Apply liberally over whole body after bathing
4. Avoid skin trauma (Koebner phenomenon). Phototherapy evaluation if no response in 4 weeks.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 20 (Kriti Sanon): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000020';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      '19-year-old with widespread inflammatory papules, pustules, and deep painful nodular cysts on cheeks, forehead, and jawline with early ice-pick scarring. Previous topical therapies ineffective. Baseline liver and lipid panels normal.',
      '1. Cap Isotretinoin 20mg - 1 capsule once daily with fatty dinner (30 days)
2. Gel Clindamycin 1% + Nicotinamide 4% - Apply morning on affected areas
3. Broad-spectrum Non-comedogenic Sunscreen SPF 50 - Apply 20 minutes before outdoor exposure
4. Important: Strict pregnancy avoidance and double contraception counseling provided and signed.',
      r2, now() - interval '2 hours');

  -- Patient 21 (Varun Dhawan): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000021';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      'Recurrent wheals and itchy urticarial plaques erupting daily across limbs and trunk for over 8 weeks, each lasting 4-12 hours. Exaggerated wheal response upon light mechanical scratching (dermographism). Serum IgE 410 IU/mL.',
      '1. Tab Bilastine 20mg - 1 tablet once daily in the morning on an empty stomach (30 days)
2. Tab Fexofenadine 180mg - 1 tablet SOS in the evening if breakthrough itching occurs
3. Calamine lotion with Aloe Vera - Apply topically for symptomatic pruritus relief
4. Avoid hot showers, friction tight clothing, and NSAIDs.');

  -- Patient 22 (Tanvi Deshmukh): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000022';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 23 (Gaurav Bajaj): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000023';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 24 (Alok Tripathi): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000024';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- =========================================================================
  -- DOCTOR 5: Dr. Rajesh Kulkarni (Orthopedic Surgeon)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000005';

  -- Patient 25 (Bhaskar Murthy): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000025';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      '62-year-old presenting with bilateral medial knee joint pain, morning stiffness lasting 25 minutes, and difficulty negotiating stairs. Right knee shows palpable crepitus, medial joint line tenderness, and mild joint effusion. Standing AP X-ray: medial joint space narrowing, subchondral sclerosis, and marginal osteophytes.',
      '1. Tab Diacerein 50mg + Glucosamine Sulfate 750mg - 1 tablet twice daily after meals (60 days)
2. Tab Aceclofenac 100mg + Paracetamol 325mg - 1 tablet SOS after meals for severe flares
3. Gel Diclofenac Diethylamine 1.16% - Apply locally thrice daily without vigorous massage
4. Isometric quadriceps and hamstring strengthening exercises under physiotherapy guidance. Weight loss target: 5 kg.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 26 (Sunita Chatterjee): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000026';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      'Sharp, shooting electric-shock like lower back pain radiating down left posterolateral thigh and calf into dorsum of foot. Left straight leg raising (SLR) test positive at 40 degrees. Mild weakness in left great toe dorsiflexion (EHL grade 4/5). MRI Lumbar spine confirms L4-L5 paracentral disc protrusion compressing traversing L5 root.',
      '1. Cap Pregabalin 75mg + Methylcobalamin 1500mcg - 1 capsule at bedtime (30 days)
2. Tab Etoricoxib 90mg - 1 tablet once daily after breakfast for 7 days
3. Tab Thiocolchicoside 4mg - 1 tablet twice daily for 5 days
4. Lumbo-sacral support belt during walking/travel. Avoid forward bending and lifting heavy weights. Core stabilization physiotherapy.',
      r2, now() - interval '2 hours');

  -- Patient 27 (Pradeep Kadam): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000027';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      'Gradual onset severe nocturnal shoulder pain and progressive restriction of both active and passive motion over 3 months. Glenohumeral abduction restricted to 70 degrees, external rotation restricted to 15 degrees. Rotator cuff cuff intact on ultrasound.',
      '1. Administered: Intra-articular Methylprednisolone 40mg + 2% Lignocaine into posterior glenohumeral joint
2. Tab Tramadol 37.5mg + Paracetamol 325mg - 1 tablet SOS at bedtime for severe night pain
3. Tab Deflazacort 6mg - 1 tablet daily for 5 days
4. Supervised physiotherapy: Codman''s pendulum exercises, wall climbing, overhead pulley mobilization.');

  -- Patient 28 (Leela Krishnan): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000028';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 29 (Chetan Shrestha): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000029';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 30 (Vandana Prabhu): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000030';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- =========================================================================
  -- DOCTOR 6: Dr. Ananya Sen (Neurologist)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000006';

  -- Patient 31 (Deepak Varma): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000031';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      '32-year-old experiencing pulsating, unilateral throbbing headaches 12-14 days per month for 6 months. Accompanied by shimmering zigzag lights (scintillating scotoma) lasting 20 minutes before headache onset, severe photophobia, phonophobia, and nausea. Brain MRI with contrast normal.',
      '1. Tab Propranolol 40mg ER - 1 tablet once daily morning (prophylaxis, 30 days)
2. Tab Topiramate 25mg - 1 tablet at night, increase to 50mg after 2 weeks (prophylaxis)
3. Tab Rizatriptan 10mg orally disintegrating - 1 tablet at aura/headache onset, can repeat once after 2 hours if needed
4. Tab Naproxen 500mg SOS with triptan. Maintain headache diary. Regulate sleep and meal timings.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 32 (Maya Namboodiri): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000032';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      '64-year-old presenting with insidious onset right hand 4-5 Hz resting pill-rolling tremor, micrographia, and slowness in buttoning shirts. Neurological exam reveals unilateral cogwheel rigidity at right wrist and elbow, reduced right arm swing during ambulation, and mild masked facies.',
      '1. Tab Levodopa 100mg + Carbidopa 25mg - 1/2 tablet thrice daily 30 minutes before meals for 10 days, then 1 tablet thrice daily
2. Tab Pramipexole 0.375mg ER - 1 tablet at bedtime
3. High-protein foods to be taken primarily with evening meals to optimize L-dopa absorption.
4. Occupational therapy and gait balance physiotherapy program.',
      r2, now() - interval '2 hours');

  -- Patient 33 (Ashok Ganguly): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000033';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      '10-year history of diabetes. Complains of persistent burning feet, painful hyperesthesia, and tingling paresthesias disturbing sleep. Neurological examination: Loss of vibration sense to 128Hz tuning fork at hallux, absent ankle jerks bilaterally, impaired 10g monofilament perception at 4 planter sites.',
      '1. Tab Duloxetine 30mg - 1 tablet daily in the morning with food (titrate to 60mg in 2 weeks)
2. Tab Gabapentin 300mg - 1 tablet at bedtime (30 days)
3. Strict glycemic control target HbA1c < 7.0%.
4. Diabetic foot care guidelines: daily inspection, moisture between toes avoided, seamless padded socks.');

  -- Patient 34 (Jyoti Pandey): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000034';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 35 (Karthik Raman): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000035';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 36 (Swati Deshpande): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000036';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 1, '11:30', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- =========================================================================
  -- DOCTOR 7: Dr. Vikramaditya Joshi (ENT Specialist)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000007';

  -- Patient 37 (Girish Mahajan): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000037';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      'Intermittent, painless, non-foul-smelling mucoid discharge from left ear for 1 year, accompanied by mild hearing loss. Otoscopy: Large central perforation in pars tensa of left tympanic membrane with pale, moist middle ear mucosa. Audiogram reveals 32 dB conductive hearing loss on left side.',
      '1. Ear Drops Ciprofloxacin 0.3% + Dexamethasone 0.1% - 4 drops in left ear thrice daily for 7 days
2. Keep ear strictly dry: place cotton soaked in vaseline/oil in ear canal during baths
3. Avoid swimming and water sports. Tab Cefuroxime Axetil 500mg twice daily for 5 days
4. Elective Tympanoplasty scheduled in 4 weeks after ear remains dry for 3 weeks.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 38 (Pallavi Gokhale): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000038';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      'Bilateral nasal obstruction, thick yellowish post-nasal drip, reduced sense of smell (hyposmia), and facial fullness over maxillary sinuses for 8 months. Anterior rhinoscopy: Multiple bilateral smooth, pale, grape-like polypoidal masses in middle meatus. Non-contrast CT PNS confirms mucosal thickening and ethmoidal opacification.',
      '1. Fluticasone Furoate Nasal Spray 27.5mcg - 2 sprays in each nostril once daily morning (long term)
2. Tab Deflazacort 30mg once daily for 5 days, tapered down by 6mg every 3 days (15-day course)
3. Isotonic nasal saline irrigation (Neti pot) - 200ml per nostril twice daily
4. Functional Endoscopic Sinus Surgery (FESS) consult booked for surgical clearance.',
      r2, now() - interval '2 hours');

  -- Patient 39 (Sumit Mathur): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000039';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      'Severe throat pain, odynophagia (painful swallowing), fever of 102.2 F, and headache for 2 days. Examination: Enlarged, fiery red tonsils covered with creamy white follicular exudates, uvula swollen, tender anterior cervical lymphadenopathy. Centor criteria score = 4.',
      '1. Tab Amoxicillin 500mg + Potassium Clavulanate 125mg - 1 tablet twice daily for 7 days (complete full course)
2. Tab Ibuprofen 400mg + Paracetamol 325mg - 1 tablet thrice daily after meals for 3 days
3. Povidone-Iodine 1% or Chlorhexidine mouthwash / gargle - 10ml diluted in equal warm water thrice daily
4. Warm soothing liquids, soft swallowable food, rest.');

  -- Patient 40 (Anjali Mishra): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000040';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 41 (Naveen Yadav): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000041';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 42 (Preeti Chadha): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000042';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 2, '11:30', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- =========================================================================
  -- DOCTOR 8: Dr. Pooja Deshmukh (Gynecologist)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000008';

  -- Patient 43 (Shweta Tiwari): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000043';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      '24-year-old presenting with oligomenorrhea (cycle interval 45-65 days), moderate facial hirsutism (Ferriman-Gallwey score 12), and refractory acne. Pelvic ultrasound: Bilateral enlarged ovaries (volume > 10 mL) with >= 20 peripheral subcentimeter follicles (''string-of-pearls'' appearance). Hormonal assay: LH/FSH ratio 2.8, Free Testosterone elevated.',
      '1. Combined Oral Contraceptive (Ethinylestradiol 0.035mg + Cyproterone Acetate 2mg) - 1 tablet daily for 21 days starting cycle day 1, repeat for 6 cycles
2. Tab Metformin 500mg ER - 1 tablet twice daily with food (improves insulin sensitivity)
3. Sachet Myo-Inositol 2000mg + D-Chiro-Inositol 50mg - 1 sachet daily in water
4. Structured lifestyle intervention: 45 min daily cardio + resistance exercise, low glycemic index diet.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 44 (Radhika Apte): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000044';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      'Primigravida at 22 weeks 4 days. General exam: BP 112/72 mmHg, Weight 58.4 kg (weight gain 4.2 kg to date). Fundal height corresponds to 22 weeks, Fetal Heart Rate 146 bpm regular. Level II Target Ultrasound Scan (TIFFA) reviewed: Normal fetal anatomy, no structural anomalies, anterior placenta high up, adequate amniotic fluid (AFI 14 cm).',
      '1. Tab Ferrous Ascorbate 100mg + Folic Acid 1.5mg - 1 tablet daily after lunch (continue throughout pregnancy)
2. Tab Calcium Carbonate 500mg + Vitamin D3 250 IU - 1 tablet twice daily after breakfast and dinner (separate from iron by 2 hours)
3. Tdap Vaccine (Tetanus, Diphtheria, Pertussis) - scheduled at 26 weeks
4. Counselled on daily fetal kick count (DFKC), warning signs (bleeding, leaking, severe headache, epigastric pain).',
      r2, now() - interval '2 hours');

  -- Patient 45 (Madhuri Bhat): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000045';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      '49-year-old woman experiencing 8-10 debilitating hot flashes and night drenching sweats per 24 hours, insomnia, emotional irritability, and irregular menstrual cycle spacing. Pelvic ultrasound shows normal endometrial thickness (3.8 mm). Mammogram within last 6 months negative.',
      '1. Tab Desvenlafaxine 50mg - 1 tablet once daily morning (non-hormonal vasomotor symptom control)
2. Cap Evening Primrose Oil 1000mg - 1 capsule twice daily after meals (60 days)
3. Tab Calcium Carbonate 1250mg + Calcitriol 0.25mcg - 1 tablet daily after food
4. Dressing in breathable cotton layers, cool bedroom environment, stress reduction and yoga.');

  -- Patient 46 (Sandeep Kulkarni): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000046';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 47 (Ritu Rawat): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000047';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 48 (Smita Patil): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000048';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 3, '11:30', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- =========================================================================
  -- DOCTOR 9: Dr. Siddharth Nambiar (Ophthalmologist)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000009';

  -- Patient 49 (Omkar Joshi): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000049';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      '60-year-old with family history of glaucoma. Best corrected visual acuity (BCVA) 6/6 in both eyes. Goldmann applanation tonometry: Intraocular Pressure (IOP) OD 27 mmHg, OS 25 mmHg. Gonioscopy shows open anterior chamber angles (Shaffer Grade IV). Funduscopy: Cup-to-disc ratio OD 0.7, OS 0.65 with neuroretinal rim thinning. Humphrey Visual Field 24-2 reveals early superior arcuate defect OD.',
      '1. Eye Drops Latanoprost 0.005% - 1 drop in both eyes once daily strictly at bedtime (target IOP < 18 mmHg)
2. Eye Drops Timolol Maleate 0.5% - 1 drop in both eyes once daily in the morning (avoid if asthma/bradycardia)
3. Digital punctal occlusion technique demonstrated to patient to minimize systemic absorption
4. Optical Coherence Tomography (OCT) of RNFL and repeat IOP check scheduled in 4 weeks.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 50 (Nandita Das): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000050';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      'Software engineer with 10+ hours daily screen exposure. Complains of burning sensation, foreign body sensation, grittiness, fluctuating vision, and paradoxical reflex tearing. Slit-lamp exam: Tear Film Break-Up Time (TBUT) 3 seconds in both eyes (severely reduced), Schirmer I test 6 mm. Meibomian Gland Dysfunction (MGD) with inspissated meibum.',
      '1. Eye Drops Carboxymethylcellulose Sodium 0.5% (Preservative-Free) - 1 drop in both eyes 4-6 times daily
2. Eye Drops Cyclosporine 0.05% Ophthalmic Emulsion - 1 drop in both eyes twice daily 12 hours apart
3. Eye Ointment White Petrolatum + Mineral Oil - Apply small ribbon inside lower eyelids at bedtime
4. Warm eyelid compresses for 10 minutes daily followed by gentle eyelid massage. 20-20-20 rule implemented.',
      r2, now() - interval '2 hours');

  -- Patient 51 (Jagdish Chandra): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000051';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      '67-year-old experiencing progressive, painless, gradual diminution of distant vision and glare while driving at night for 1 year. BCVA OD 6/18, OS 6/24, improving with pinhole to 6/12 OD, 6/18 OS. Slit-lamp biomicroscopy: Golden-yellow nuclear sclerosis Grade 2 with anterior cortical radial spokes. Dilated fundus examination normal without diabetic retinopathy.',
      '1. Eye Drops Nepafenac 0.1% - 1 drop once daily in both eyes
2. Prescribed updated intermediate and near bifocal spectacles for temporary symptomatic reading improvement
3. Anti-glare coating recommended for eyeglasses
4. Scheduled for elective Phacoemulsification with Hydrophobic Monofocal Intraocular Lens (IOL) implantation.');

  -- Patient 52 (Usha Uthup): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000052';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 53 (Mahesh Bhatt): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000053';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 54 (Geeta Govinda): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000054';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 4, '11:30', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- =========================================================================
  -- DOCTOR 10: Dr. Tanvi Bhatia (Pulmonologist)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000010';

  -- Patient 55 (Raghuram Rajan): Completed consultation on past visit + upcoming booking
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000055';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today - 3, 'completed',
      '63-year-old retired clerk with 35 pack-year cigarette smoking history. Presents with chronic morning productive cough with mucoid sputum and exertional breathlessness (mMRC Dyspnea Grade 2). Auscultation: Vesicular breath sounds with prolonged expiratory phase and scattered rhonchi. Post-bronchodilator spirometry: FEV1/FVC ratio 0.61, FEV1 62% predicted (GOLD 2). Resting SpO2 95% on room air.',
      '1. Dry Powder Inhaler Tiotropium Bromide 18mcg + Formoterol Fumarate 12mcg - 1 capsule inhalation once daily morning (long term)
2. Inhaler Levosalbutamol 50mcg - 2 puffs SOS via spacer for acute breathlessness
3. Tobacco Cessation Counseling: Nicotine transdermal patch 14mg/24hr applied daily + Nicotine gum 2mg for cravings
4. Administered: Annual Influenza vaccine & Pneumococcal conjugate (PCV13) vaccine. Pulmonary rehabilitation enrolled.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 56 (Tara Sharma): Completed consultation earlier today
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000056';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'completed', true, r2, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, p_id, d_id, today, 'completed',
      '29-year-old with daily wheezing, chest tightness, and nocturnal cough awakening patient 2-3 times per week. Uses rescue salbutamol inhaler almost daily. Absolute Eosinophil Count (AEC) 680 cells/mcL, Total Serum IgE 520 IU/mL. Spirometry demonstrates 16% and 240 mL improvement in FEV1 following 400mcg inhaled salbutamol.',
      '1. Inhaler Budesonide 200mcg + Formoterol 6mcg - 1 puff twice daily (maintenance and reliever SMART therapy)
2. Tab Montelukast Sodium 10mg - 1 tablet once daily at bedtime (30 days)
3. Tab Bilastine 20mg - 1 tablet daily before breakfast for associated allergic rhinitis
4. Rinse mouth thoroughly with water and spit out after each steroid inhalation. Peak Expiratory Flow (PEF) home diary.',
      r2, now() - interval '2 hours');

  -- Patient 57 (Vinay Pathak): IN CONSULTATION right now (active)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000057';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, p_id, d_id, today, 'in_progress',
      'Patient presents with persistent, severe, hacking paroxysmal dry cough for 12 days following an influenza-like episode. Cough causes rib cage muscle soreness and sleep disruption. Afebrile (98.4 F), SpO2 98%, lung auscultation reveals clear breath sounds bilaterally without focal consolidation, rales, or wheezing. Chest X-ray PA view clear.',
      '1. Syp Dextromethorphan Hydrobromide 10mg + Chlorpheniramine 4mg - 10ml thrice daily for 7 days
2. Tab Levocetirizine 5mg - 1 tablet at bedtime for 7 days
3. Nebulization or Inhaler Budesonide 200mcg - 1 puff twice daily for 5 days to reduce bronchial hyperresponsiveness
4. Warm honey-ginger lemon water, steam inhalation twice daily. Reassurance regarding viral cough resolution timeline.');

  -- Patient 58 (Payal Ghosh): WAITING in queue (verified)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000058';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_id, d_id, a, today, 'waiting', true, r3, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 59 (Yashwant Sinha): CHECK-IN REQUESTED (awaiting verification)
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000059';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (p_id, d_id, a, today, 'checkin_requested', false);

  -- Patient 60 (Zarina Wahab): Confirmed booking + past cancelled appointment
  select patient_id into p_id from public.patients where user_id = '22222222-2222-2222-2222-000000000060';
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today + 5, '11:30', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (p_id, d_id, today - 6, '16:00', 'cancelled');

  -- 3.9 Walk-in queue entries and consultations
  -- Suresh Kumar: waiting in Dr. Mehta's queue
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000001';
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_walk1, d_id, today, 'waiting', true, r1, now() - interval '10 minutes', now() - interval '10 minutes');

  -- Lakshmi Narayanan: waiting in Dr. Iyer's queue
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000003';
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_walk2, d_id, today, 'waiting', true, r2, now() - interval '8 minutes', now() - interval '8 minutes');

  -- Ramesh Gupta: waiting in Dr. Kulkarni's queue
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000005';
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_walk3, d_id, today, 'waiting', true, r3, now() - interval '5 minutes', now() - interval '5 minutes');

  -- Fatima Sheikh: checkin_requested for Dr. Joshi
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000007';
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified)
    values (p_walk4, d_id, today, 'checkin_requested', false);

  -- Balwinder Singh: completed walk-in consultation with Dr. Bhatia earlier today
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000010';
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (p_walk5, d_id, today, 'completed', true, r2, now() - interval '3 hours', now() - interval '3 hours') returning queue_id into q;
  insert into public.consultations(queue_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, p_walk5, d_id, today, 'completed',
      'Walk-in emergency evaluation for acute mild asthmatic wheezing triggered by dust storm. Bilateral expiratory wheezes, SpO2 96% on room air. Immediate response to office nebulization.',
      '1. Inhaler Levosalbutamol 50mcg - 2 puffs SOS via spacer\n2. Tab Montelukast 10mg - 1 tablet at night for 14 days\n3. Avoid dusty outdoor exposure, wear N95 mask.',
      r2, now() - interval '2 hours 30 minutes');

  -- 3.10 Recalculate queue positions for today across all 10 doctors
  for doc_rec in select doctor_id from public.doctors loop
    perform public.recalculate_queue(doc_rec.doctor_id, today);
  end loop;
end $$;
