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
