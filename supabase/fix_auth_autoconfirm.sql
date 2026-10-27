-- ============================================================================
-- Fix: Auto-confirm Emails, Fix Permissions (FORBIDDEN error) & Realtime Sync
-- ============================================================================
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/dadliwnisugumtwleipm/sql/new

-- 1. Auto-confirm all existing users currently stuck in unconfirmed state
update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now())
where email_confirmed_at is null;

-- 2. Automatically confirm new users on insert into auth.users (removes email confirmation requirement)
create or replace function public.handle_auto_confirm_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.email_confirmed_at is null then
    new.email_confirmed_at := now();
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_auto_confirm on auth.users;
create trigger on_auth_user_auto_confirm
  before insert on auth.users
  for each row execute function public.handle_auto_confirm_user();

-- 3. Robust patient handler on user creation
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_name text;
  v_phone text;
begin
  if new.raw_app_meta_data->>'staff' is not null then
    return new;
  end if;

  v_name := trim(coalesce(new.raw_user_meta_data->>'name', ''));
  v_phone := regexp_replace(coalesce(new.raw_user_meta_data->>'phone', ''), '[\s-]', '', 'g');

  if char_length(v_name) < 2 or char_length(v_name) > 100 then
    v_name := coalesce(nullif(trim(split_part(new.email, '@', 1)), ''), 'Patient');
  end if;

  if v_phone !~ '^\+?[0-9]{7,15}$' then
    v_phone := '+10000000000';
  end if;

  insert into public.patients(user_id, name, email, phone)
  values (new.id, v_name, lower(new.email), v_phone)
  on conflict (user_id) do update
    set name = excluded.name,
        email = excluded.email,
        phone = excluded.phone,
        updated_at = now();

  insert into public.user_roles(user_id, role)
  values (new.id, 'patient')
  on conflict do nothing;

  return new;
end $$;

-- 4. Backfill all existing auth.users who do not have patient or role records yet
-- Link existing patients by email
update public.patients p
set user_id = u.id
from auth.users u
where lower(p.email) = lower(u.email)
  and (p.user_id is null or p.user_id <> u.id);

-- Create patient record for any auth.users that don't have one (and aren't doctors/receptionists)
insert into public.patients(user_id, name, email, phone)
select
  u.id,
  coalesce(nullif(trim(u.raw_user_meta_data->>'name'), ''), nullif(trim(split_part(u.email, '@', 1)), ''), 'Patient'),
  lower(u.email),
  coalesce(nullif(regexp_replace(coalesce(u.raw_user_meta_data->>'phone', ''), '[\s-]', '', 'g'), ''), '+10000000000')
from auth.users u
where not exists (select 1 from public.patients p where p.user_id = u.id)
  and not exists (select 1 from public.doctors d where d.user_id = u.id)
  and not exists (select 1 from public.receptionists r where r.user_id = u.id)
on conflict (user_id) do nothing;

-- Ensure patient role is assigned in user_roles
insert into public.user_roles(user_id, role)
select u.id, 'patient'::public.app_role
from auth.users u
where not exists (select 1 from public.doctors d where d.user_id = u.id)
  and not exists (select 1 from public.receptionists r where r.user_id = u.id)
on conflict do nothing;

-- 5. Resilient current_patient_id() and has_role() functions
create or replace function public.current_patient_id()
returns int language sql stable security definer set search_path = public as $$
  select patient_id from public.patients
  where user_id = auth.uid()
     or (email is not null and email = lower(coalesce(auth.jwt()->>'email', '')))
  order by (case when user_id = auth.uid() then 0 else 1 end)
  limit 1;
$$;

create or replace function public.has_role(_uid uuid, _role public.app_role)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_roles where user_id = _uid and role = _role
    union all
    -- If checking patient role, any authenticated user who is not a doctor or receptionist qualifies
    select 1 where _role = 'patient'
      and not exists (select 1 from public.doctors d where d.user_id = _uid)
      and not exists (select 1 from public.receptionists r where r.user_id = _uid)
  );
$$;

-- 6. Self-healing book_appointment RPC (fixes "You don't have permission to do that")
create or replace function public.book_appointment(p_doctor_id int, p_date date, p_time time)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt()->>'email', ''));
  v_pid int;
  v_id int;
  v_ok boolean;
begin
  if v_uid is null then
    raise exception 'FORBIDDEN: You must be logged in to book an appointment';
  end if;

  -- 1. Resolve patient_id, auto-linking if needed
  select patient_id into v_pid
  from public.patients
  where user_id = v_uid limit 1;

  if v_pid is null and v_email <> '' then
    select patient_id into v_pid
    from public.patients
    where email = v_email limit 1;

    if v_pid is not null then
      update public.patients set user_id = v_uid where patient_id = v_pid;
    end if;
  end if;

  -- If patient record still doesn't exist, create it on-the-fly
  if v_pid is null then
    insert into public.patients(user_id, name, email, phone)
    select
      v_uid,
      coalesce(nullif(trim(u.raw_user_meta_data->>'name'), ''), nullif(trim(split_part(u.email, '@', 1)), ''), 'Patient'),
      lower(u.email),
      coalesce(nullif(regexp_replace(coalesce(u.raw_user_meta_data->>'phone', ''), '[\s-]', '', 'g'), ''), '+10000000000')
    from auth.users u
    where u.id = v_uid
    returning patient_id into v_pid;
  end if;

  -- Ensure patient role is present
  insert into public.user_roles(user_id, role)
  values (v_uid, 'patient')
  on conflict do nothing;

  if v_pid is null then
    raise exception 'FORBIDDEN: Patient profile not found';
  end if;

  if p_date < clinic_today() or p_date > clinic_today() + 30 then
    raise exception 'DATE_OUT_OF_RANGE: Date must be within the next 30 days';
  end if;

  select s.is_available into v_ok
  from get_available_slots(p_doctor_id, p_date) s
  where s.slot_time = p_time;

  if v_ok is null then
    raise exception 'SLOT_INVALID: That time is not a valid slot';
  end if;

  if not v_ok then
    raise exception 'SLOT_TAKEN: That slot is no longer available';
  end if;

  if exists (
    select 1 from appointments
    where patient_id = v_pid
      and appointment_date = p_date
      and appointment_time = p_time
      and status in ('booked','confirmed','checked_in')
  ) then
    raise exception 'PATIENT_CONFLICT: You already have an appointment at this time';
  end if;

  begin
    insert into appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (v_pid, p_doctor_id, p_date, p_time, 'booked')
    returning appointment_id into v_id;
  exception when unique_violation then
    raise exception 'SLOT_TAKEN: That slot is no longer available';
  end;

  update appointments set status = 'confirmed' where appointment_id = v_id;
  return v_id;
end $$;

-- 7. Ensure Realtime publication & replica identity for live sync across roles
alter table public.queue_entries replica identity full;
alter table public.appointments replica identity full;
alter table public.consultations replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.appointments;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.queue_entries;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.consultations;
  exception when duplicate_object then null;
  end;
end $$;
