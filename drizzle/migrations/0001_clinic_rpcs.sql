
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
