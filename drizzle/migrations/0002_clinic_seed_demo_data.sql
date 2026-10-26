
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
