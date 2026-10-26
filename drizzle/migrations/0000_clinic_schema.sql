
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
