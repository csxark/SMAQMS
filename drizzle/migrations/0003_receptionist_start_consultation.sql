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