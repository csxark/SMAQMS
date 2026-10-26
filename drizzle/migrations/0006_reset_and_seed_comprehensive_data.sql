-- Migration: Revised Seed Data (5 Doctors, 1 Receptionist, 12-13 Patients each)
-- Patients are seeded WITHOUT auth users -- they MUST create their own accounts to log in.
-- Staff (doctors + receptionist) have demo logins. Password for all staff: Smaqms#2026

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
  r1 int;
  d_id int;
  pid1 int; pid2 int; pid3 int; pid4 int; pid5 int;
  pid6 int; pid7 int; pid8 int; pid9 int; pid10 int;
  pid11 int; pid12 int; pid13 int;
  a int;
  q int;
  doc_rec record;
begin
  -- =========================================================================
  -- 3.1 Insert Auth Users & Identities for Staff ONLY (5 Doctors + 1 Receptionist)
  --     Patients do NOT get auth users -- they must self-register.
  -- =========================================================================
  for u in select * from (values
    ('11111111-1111-1111-1111-000000000001'::uuid, 'aarav.mehta@example.com',     'Dr. Aarav Mehta'),
    ('11111111-1111-1111-1111-000000000002'::uuid, 'neha.kapoor@example.com',     'Dr. Neha Kapoor'),
    ('11111111-1111-1111-1111-000000000003'::uuid, 'rohan.iyer@example.com',      'Dr. Rohan Iyer'),
    ('11111111-1111-1111-1111-000000000004'::uuid, 'shalini.verma@example.com',   'Dr. Shalini Verma'),
    ('11111111-1111-1111-1111-000000000005'::uuid, 'rajesh.kulkarni@example.com', 'Dr. Rajesh Kulkarni'),
    ('11111111-1111-1111-2222-000000000001'::uuid, 'priya.sharma@example.com',    'Priya Sharma')
  ) as t(id, email, name) loop
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

  -- =========================================================================
  -- 3.2 Insert Doctors
  -- =========================================================================
  insert into public.doctors(user_id, name, specialization, slot_minutes) values
    ('11111111-1111-1111-1111-000000000001', 'Dr. Aarav Mehta',     'General Physician',  15),
    ('11111111-1111-1111-1111-000000000002', 'Dr. Neha Kapoor',     'Pediatrician',       15),
    ('11111111-1111-1111-1111-000000000003', 'Dr. Rohan Iyer',      'Cardiologist',       20),
    ('11111111-1111-1111-1111-000000000004', 'Dr. Shalini Verma',   'Dermatologist',      15),
    ('11111111-1111-1111-1111-000000000005', 'Dr. Rajesh Kulkarni', 'Orthopedic Surgeon', 20);

  -- =========================================================================
  -- 3.3 Insert Receptionist (single)
  -- =========================================================================
  insert into public.receptionists(user_id, name, email) values
    ('11111111-1111-1111-2222-000000000001', 'Priya Sharma', 'priya.sharma@example.com');

  -- =========================================================================
  -- 3.4 Insert Staff User Roles
  -- =========================================================================
  insert into public.user_roles(user_id, role) values
    ('11111111-1111-1111-1111-000000000001', 'doctor'),
    ('11111111-1111-1111-1111-000000000002', 'doctor'),
    ('11111111-1111-1111-1111-000000000003', 'doctor'),
    ('11111111-1111-1111-1111-000000000004', 'doctor'),
    ('11111111-1111-1111-1111-000000000005', 'doctor'),
    ('11111111-1111-1111-2222-000000000001', 'receptionist');

  -- =========================================================================
  -- 3.5 Doctor Availability: Mon-Sat, 09:00-13:00 and 14:00-18:00
  -- =========================================================================
  insert into public.doctor_availability(doctor_id, day_of_week, start_time, end_time)
  select d.doctor_id, dow, s, e
  from public.doctors d
  cross join generate_series(1, 6) dow
  cross join (values ('09:00'::time, '13:00'::time), ('14:00'::time, '18:00'::time)) w(s, e);

  select receptionist_id into r1 from public.receptionists where email = 'priya.sharma@example.com';

  -- =========================================================================
  -- DOCTOR 1: Dr. Aarav Mehta (General Physician)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000001';

  insert into public.patients(name, phone) values ('Ananya Rao',     '+919810000001') returning patient_id into pid1;
  insert into public.patients(name, phone) values ('Vikram Singh',   '+919810000002') returning patient_id into pid2;
  insert into public.patients(name, phone) values ('Kabir Das',      '+919810000003') returning patient_id into pid3;
  insert into public.patients(name, phone) values ('Meera Nair',     '+919810000004') returning patient_id into pid4;
  insert into public.patients(name, phone) values ('Arjun Patel',    '+919810000005') returning patient_id into pid5;
  insert into public.patients(name, phone) values ('Sneha Reddy',    '+919810000006') returning patient_id into pid6;
  insert into public.patients(name, phone) values ('Rohit Khanna',   '+919810000007') returning patient_id into pid7;
  insert into public.patients(name, phone) values ('Divya Menon',    '+919810000008') returning patient_id into pid8;
  insert into public.patients(name, phone) values ('Karan Mehta',    '+919810000009') returning patient_id into pid9;
  insert into public.patients(name, phone) values ('Pooja Iyer',     '+919810000010') returning patient_id into pid10;
  insert into public.patients(name, phone) values ('Suresh Kumar',   '+919810000011') returning patient_id into pid11;
  insert into public.patients(name, phone) values ('Lakshmi Pillai', '+919810000012') returning patient_id into pid12;
  insert into public.patients(name, phone) values ('Rajan Verma',    '+919810000013') returning patient_id into pid13;

  -- Patient 1: Completed 3 days ago + upcoming booking
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid1, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid1, d_id, today - 3, 'completed',
      'Patient presented with 2-day history of acute watery diarrhea, nausea, low-grade fever (99.2 F), and generalized abdominal cramping. Vitals: BP 118/76 mmHg, HR 84 bpm, SpO2 98%.',
      '1. ORS Electrolyte Solution - 1 packet in 1L water, sip frequently (min 2L/day)
2. Tab Ondansetron 4mg - 1 tab 30 mins before meals SOS for nausea
3. Cap Bacillus clausii (Probiotic) - 1 capsule twice daily for 5 days
4. Bland BRAT diet. Avoid dairy, greasy, spicy food. Review if fever > 101 F.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 2: Completed earlier today
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid2, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid2, d_id, a, today, 'completed', true, r1, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid2, d_id, today, 'completed',
      'Routine follow-up. Morning occipital headaches. BP 152/94 mmHg bilateral. BMI 28.2. Lipids: TC 228, LDL 148, TG 190 mg/dL. ECG unremarkable.',
      '1. Tab Telmisartan 40mg + Amlodipine 5mg - 1 tablet daily morning after breakfast (30 days)
2. Tab Atorvastatin 10mg - 1 tablet at bedtime (30 days)
3. Low salt (< 2g/day), aerobic exercise 30 min 5x/week. Recheck BP in 2 weeks.',
      r1, now() - interval '2 hours');

  -- Patient 3: IN CONSULTATION right now
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid3, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid3, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, pid3, d_id, today, 'in_progress',
      'Worsening lethargy, polyuria, polydipsia over 3 weeks. FBS 188, PPBS 264 mg/dL, HbA1c 8.6%. Microalbuminuria ACR 45. Peripheral pulses palpable.',
      '1. Tab Metformin 1000mg ER - 1 tablet twice daily with meals (30 days)
2. Tab Glimepiride 1mg - 1 tablet once daily before breakfast
3. Diabetic diet: complex carbs, high fiber, eliminate refined sugar.
4. SMBG twice weekly. MNT consult ordered.');

  -- Patient 4: WAITING in queue
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid4, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid4, d_id, a, today, 'waiting', true, r1, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 5: CHECK-IN REQUESTED
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid5, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (pid5, d_id, a, today, 'checkin_requested', false);

  -- Patient 6: Confirmed afternoon + past cancelled
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today - 6, '16:00', 'cancelled');

  -- Patient 7: Completed 5 days ago
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid7, d_id, today - 5, '09:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid7, d_id, a, today - 5, 'completed', true, r1, now() - interval '5 days 4 hours', now() - interval '5 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid7, d_id, today - 5, 'completed',
      'Acute-onset sore throat, dry cough, fever 100.8 F for 2 days. Oropharynx erythematous, no exudates. Lungs clear.',
      '1. Tab Amoxicillin 500mg - 1 tablet TID for 5 days
2. Tab Paracetamol 500mg - every 6 hours SOS for fever
3. Warm saline gargles TID. Hydration and rest.',
      r1, now() - interval '5 days 3 hours');

  -- Patient 8: Upcoming appointment tomorrow
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid8, d_id, today + 1, '11:00', 'confirmed');

  -- Patient 9: Past cancelled + upcoming confirmed
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid9, d_id, today - 10, '14:00', 'cancelled');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid9, d_id, today + 3, '09:00', 'confirmed');

  -- Patient 10: Walk-in waiting today (no appointment)
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid10, d_id, today, 'waiting', true, r1, now() - interval '5 minutes', now() - interval '5 minutes');

  -- Patient 11: Completed 1 week ago
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid11, d_id, today - 7, '09:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid11, d_id, a, today - 7, 'completed', true, r1, now() - interval '7 days 4 hours', now() - interval '7 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid11, d_id, today - 7, 'completed',
      'Hypertension follow-up. BP 138/86 mmHg on current medication. Compliant. No edema. eGFR 68 stable.',
      '1. Continue Tab Amlodipine 5mg once daily
2. Tab Losartan 50mg added once daily
3. Sodium restriction reinforced. Repeat labs in 4 weeks.',
      r1, now() - interval '7 days 3 hours');

  -- Patient 12: Upcoming in 2 days
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid12, d_id, today + 2, '10:00', 'confirmed');

  -- Patient 13: Completed 2 weeks ago + upcoming follow-up
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid13, d_id, today - 14, '14:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid13, d_id, a, today - 14, 'completed', true, r1, now() - interval '14 days 4 hours', now() - interval '14 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid13, d_id, today - 14, 'completed',
      'Fatigue, weight gain, cold intolerance, constipation x 3 months. TSH 12.4 mIU/L (high), Free T4 0.6 ng/dL (low). Dx: Primary Hypothyroidism.',
      '1. Tab Levothyroxine 50mcg - on empty stomach every morning, 30 min before food
2. Avoid iron/calcium within 4 hours of dose
3. Repeat TSH after 6 weeks.',
      r1, now() - interval '14 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid13, d_id, today + 14, '10:00', 'confirmed');

  -- =========================================================================
  -- DOCTOR 2: Dr. Neha Kapoor (Pediatrician)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000002';

  insert into public.patients(name, phone) values ('Aarohi Gupta',     '+919820000001') returning patient_id into pid1;
  insert into public.patients(name, phone) values ('Devansh Bose',     '+919820000002') returning patient_id into pid2;
  insert into public.patients(name, phone) values ('Ishaan Malhotra',  '+919820000003') returning patient_id into pid3;
  insert into public.patients(name, phone) values ('Riya Sengupta',    '+919820000004') returning patient_id into pid4;
  insert into public.patients(name, phone) values ('Aditya Choudhury', '+919820000005') returning patient_id into pid5;
  insert into public.patients(name, phone) values ('Kavya Pillai',     '+919820000006') returning patient_id into pid6;
  insert into public.patients(name, phone) values ('Priya Nambiar',    '+919820000007') returning patient_id into pid7;
  insert into public.patients(name, phone) values ('Vivaan Sharma',    '+919820000008') returning patient_id into pid8;
  insert into public.patients(name, phone) values ('Diya Joshi',       '+919820000009') returning patient_id into pid9;
  insert into public.patients(name, phone) values ('Rehan Khan',       '+919820000010') returning patient_id into pid10;
  insert into public.patients(name, phone) values ('Ahana Mukherjee',  '+919820000011') returning patient_id into pid11;
  insert into public.patients(name, phone) values ('Shaurya Rao',      '+919820000012') returning patient_id into pid12;

  -- Patient 1: Completed 3 days ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid1, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid1, d_id, today - 3, 'completed',
      '4-year-old: intense right ear pain, fever 101.4 F for 24 hours. Otoscopy: Right TM erythematous, bulging, loss of light reflex. Left ear normal.',
      '1. Syp Amoxicillin-Clavulanate (228mg/5ml) - 5ml BD after meals for 7 days
2. Syp Paracetamol (250mg/5ml) - 5ml every 6 hours SOS
3. Syp Levocetirizine (2.5mg/5ml) - 2.5ml at bedtime for 5 days
4. Keep ears dry. Review in 5 days or if discharge occurs.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 2: Completed today
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid2, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid2, d_id, a, today, 'completed', true, r1, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid2, d_id, today, 'completed',
      '7-year-old: dry nocturnal cough, wheezing, dyspnea after viral illness. Bilateral expiratory wheezes, SpO2 96%, RR 26/min.',
      '1. Inhaler Levosalbutamol + Ipratropium via pediatric spacer - 2 puffs TID for 5 days
2. Inhaler Budesonide 100mcg - 2 puffs BD, rinse mouth after
3. Syp Prednisolone - 5ml once daily morning for 3 days
4. Allergen avoidance: dust mites, cold air, pet dander.',
      r1, now() - interval '2 hours');

  -- Patient 3: IN CONSULTATION
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid3, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid3, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, pid3, d_id, today, 'in_progress',
      '5-year-old: pallor, low appetite, pica. CBC: Hb 8.9, MCV 66, Ferritin 8 ng/mL. Stool negative.',
      '1. Syp Ferrous Ascorbate (30mg Fe + 500mcg FA per 5ml) - 5ml once daily after dinner for 3 months
2. Syp Albendazole 400mg - single deworming dose tonight
3. Diet: green leafy veg, dates, jaggery, lentils. Avoid milk with iron syrup.');

  -- Patient 4: WAITING
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid4, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid4, d_id, a, today, 'waiting', true, r1, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 5: CHECK-IN REQUESTED
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid5, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (pid5, d_id, a, today, 'checkin_requested', false);

  -- Patient 6: Confirmed afternoon + past cancelled
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today - 6, '16:00', 'cancelled');

  -- Patient 7: Completed 5 days ago
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid7, d_id, today - 5, '09:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid7, d_id, a, today - 5, 'completed', true, r1, now() - interval '5 days 4 hours', now() - interval '5 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid7, d_id, today - 5, 'completed',
      '2-year-old: high-grade fever 103 F for 2 days, runny nose, poor feeding. Throat mildly red, no exudates. Ears clear. Likely viral URTI.',
      '1. Syp Paracetamol (250mg/5ml) - 5ml every 6 hours for fever > 100.4 F
2. Oral fluids: ORS, coconut water, diluted juice. No solids if vomiting.
3. Return if fever > 5 days, seizure, or extreme lethargy.',
      r1, now() - interval '5 days 3 hours');

  -- Patient 8: Upcoming tomorrow
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid8, d_id, today + 1, '09:30', 'confirmed');

  -- Patient 9: Walk-in checkin requested
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified)
    values (pid9, d_id, today, 'checkin_requested', false);

  -- Patient 10: Completed 1 week ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid10, d_id, today - 7, '11:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid10, d_id, a, today - 7, 'completed', true, r1, now() - interval '7 days 4 hours', now() - interval '7 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid10, d_id, today - 7, 'completed',
      '8-year-old: recurrent loose stools 4-5x/day for 4 days, cramps. Stool: Giardia cysts positive. Mild dehydration.',
      '1. Tab Metronidazole 200mg - 1 tablet TID for 7 days (complete course)
2. ORS sipped throughout day
3. Zinc sulfate syrup 10mg once daily for 14 days. Strict hand hygiene.',
      r1, now() - interval '7 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid10, d_id, today + 7, '10:00', 'confirmed');

  -- Patient 11: Upcoming in 3 days
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid11, d_id, today + 3, '09:00', 'confirmed');

  -- Patient 12: Completed 2 weeks ago
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid12, d_id, today - 14, '10:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid12, d_id, a, today - 14, 'completed', true, r1, now() - interval '14 days 4 hours', now() - interval '14 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid12, d_id, today - 14, 'completed',
      '6-year-old: sudden onset intense itchy raised bumps after eating prawns. Lip and periorbital swelling. SpO2 normal. Urticaria with mild angioedema.',
      '1. Syp Levocetirizine 2.5mg - 5ml at night for 5 days
2. Tab Deflazacort 6mg (crushed) - once daily for 3 days
3. Avoid shellfish completely. Allergy testing in 6 weeks.',
      r1, now() - interval '14 days 3 hours');

  -- =========================================================================
  -- DOCTOR 3: Dr. Rohan Iyer (Cardiologist)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000003';

  insert into public.patients(name, phone) values ('Harish Venkatesh', '+919830000001') returning patient_id into pid1;
  insert into public.patients(name, phone) values ('Nalini Sundaram',  '+919830000002') returning patient_id into pid2;
  insert into public.patients(name, phone) values ('Rahul Saxena',     '+919830000003') returning patient_id into pid3;
  insert into public.patients(name, phone) values ('Shilpa Agarwal',   '+919830000004') returning patient_id into pid4;
  insert into public.patients(name, phone) values ('Manjunath Hegde',  '+919830000005') returning patient_id into pid5;
  insert into public.patients(name, phone) values ('Chandan Roy',      '+919830000006') returning patient_id into pid6;
  insert into public.patients(name, phone) values ('Savita Bhatt',     '+919830000007') returning patient_id into pid7;
  insert into public.patients(name, phone) values ('Dilip Kumar',      '+919830000008') returning patient_id into pid8;
  insert into public.patients(name, phone) values ('Sunanda Rao',      '+919830000009') returning patient_id into pid9;
  insert into public.patients(name, phone) values ('Naresh Mishra',    '+919830000010') returning patient_id into pid10;
  insert into public.patients(name, phone) values ('Leena Kapoor',     '+919830000011') returning patient_id into pid11;
  insert into public.patients(name, phone) values ('Gopal Menon',      '+919830000012') returning patient_id into pid12;
  insert into public.patients(name, phone) values ('Kavitha Raman',    '+919830000013') returning patient_id into pid13;

  -- Patient 1: Completed 3 days ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid1, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid1, d_id, today - 3, 'completed',
      'Known IHD. Retrosternal chest tightness on climbing 2 flights of stairs, relieved by rest. ECG: ST depression II, III, aVF. Echo: LVEF 55%, mild anterior hypokinesia.',
      '1. Tab Aspirin 75mg + Atorvastatin 20mg - 1 capsule daily after dinner (30 days)
2. Tab Metoprolol Succinate 50mg ER - 1 tablet daily morning
3. Tab Isosorbide Mononitrate 30mg SR - 1 tablet daily morning after food
4. Tab Sorbitrate 5mg sublingual for acute angina. ER if pain > 10 min.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 2: Completed today
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid2, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid2, d_id, a, today, 'completed', true, r1, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid2, d_id, today, 'completed',
      'Progressive exertional dyspnea (NYHA Class III), bilateral pitting pedal edema, orthopnea. JVP elevated. Echo: LVEF 36%. BNP 680 pg/mL.',
      '1. Tab Sacubitril/Valsartan 24/26mg - 1 tablet twice daily
2. Tab Furosemide 40mg - 1 tablet morning on empty stomach (30 days)
3. Tab Spironolactone 25mg - 1 tablet once daily
4. Tab Empagliflozin 10mg once daily with lunch. Fluid restriction 1.5L/day, daily weight.',
      r1, now() - interval '2 hours');

  -- Patient 3: IN CONSULTATION
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid3, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid3, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, pid3, d_id, today, 'in_progress',
      'Sudden palpitations, lightheadedness, chest flutter lasting 30-45 min. ECG: irregularly irregular, absent P waves, HR 132 bpm. CHA2DS2-VASc = 3.',
      '1. Tab Apixaban 5mg - 1 tablet twice daily (30 days)
2. Tab Bisoprolol Fumarate 5mg - 1 tablet once daily morning
3. Electrolyte panel ordered. Cardiac EP follow-up in 3 weeks.
4. Avoid caffeine, alcohol, decongestants, heavy exertion.');

  -- Patient 4: WAITING
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid4, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid4, d_id, a, today, 'waiting', true, r1, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 5: CHECK-IN REQUESTED
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid5, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (pid5, d_id, a, today, 'checkin_requested', false);

  -- Patient 6: Confirmed + past cancelled
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today - 6, '16:00', 'cancelled');

  -- Patient 7: Completed 5 days ago
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid7, d_id, today - 5, '09:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid7, d_id, a, today - 5, 'completed', true, r1, now() - interval '5 days 4 hours', now() - interval '5 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid7, d_id, today - 5, 'completed',
      '58-year-old hypertensive. BP on arrival 200/118 mmHg. Papilledema on fundoscopy. ECG: LVH. Hypertensive urgency.',
      '1. Tab Amlodipine 10mg stat oral
2. Tab Clonidine 0.15mg now, repeat after 1 hr if BP > 180/110
3. Bed rest, BP monitoring every 30 min for 4 hrs. Admission for BP titration.',
      r1, now() - interval '5 days 3 hours');

  -- Patient 8: Upcoming tomorrow
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid8, d_id, today + 1, '11:00', 'confirmed');

  -- Patient 9: Walk-in waiting today
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid9, d_id, today, 'waiting', true, r1, now() - interval '7 minutes', now() - interval '7 minutes');

  -- Patient 10: Completed 1 week ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid10, d_id, today - 7, '09:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid10, d_id, a, today - 7, 'completed', true, r1, now() - interval '7 days 4 hours', now() - interval '7 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid10, d_id, today - 7, 'completed',
      '45-year-old dyslipidemia: TC 258, LDL 180, HDL 34 mg/dL. Family history MI at 52. Framingham risk 14%.',
      '1. Tab Rosuvastatin 20mg - 1 tablet at bedtime
2. Tab Omega-3 1g - 1 capsule twice daily with food
3. Mediterranean diet. Exercise 150 min/week. Repeat lipid panel in 6 weeks.',
      r1, now() - interval '7 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid10, d_id, today + 14, '09:30', 'confirmed');

  -- Patient 11: Upcoming in 2 days
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid11, d_id, today + 2, '14:00', 'confirmed');

  -- Patient 12: Completed 2 weeks ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid12, d_id, today - 14, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid12, d_id, a, today - 14, 'completed', true, r1, now() - interval '14 days 4 hours', now() - interval '14 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid12, d_id, today - 14, 'completed',
      '70-year-old: HR 42 bpm, fatigue, presyncope on exertion. Holter: complete AV dissociation (3rd degree heart block). Echo: normal LV function.',
      '1. Permanent Pacemaker implantation recommended and scheduled.
2. Tab Atropine 0.6mg available SOS for extreme bradycardia pending procedure.
3. No strenuous exertion. Daily pulse monitoring.',
      r1, now() - interval '14 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid12, d_id, today + 21, '09:00', 'confirmed');

  -- Patient 13: Upcoming in 4 days
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid13, d_id, today + 4, '14:30', 'confirmed');

  -- =========================================================================
  -- DOCTOR 4: Dr. Shalini Verma (Dermatologist)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000004';

  insert into public.patients(name, phone) values ('Tanvi Deshmukh',   '+919840000001') returning patient_id into pid1;
  insert into public.patients(name, phone) values ('Gaurav Bajaj',     '+919840000002') returning patient_id into pid2;
  insert into public.patients(name, phone) values ('Alok Tripathi',    '+919840000003') returning patient_id into pid3;
  insert into public.patients(name, phone) values ('Preethi Sundaram', '+919840000004') returning patient_id into pid4;
  insert into public.patients(name, phone) values ('Radheshyam Yadav', '+919840000005') returning patient_id into pid5;
  insert into public.patients(name, phone) values ('Sunita Reddy',     '+919840000006') returning patient_id into pid6;
  insert into public.patients(name, phone) values ('Mohan Lal',        '+919840000007') returning patient_id into pid7;
  insert into public.patients(name, phone) values ('Deepa Nair',       '+919840000008') returning patient_id into pid8;
  insert into public.patients(name, phone) values ('Vinod Patel',      '+919840000009') returning patient_id into pid9;
  insert into public.patients(name, phone) values ('Anita Srivastava', '+919840000010') returning patient_id into pid10;
  insert into public.patients(name, phone) values ('Rajneesh Gupta',   '+919840000011') returning patient_id into pid11;
  insert into public.patients(name, phone) values ('Meenakshi Iyer',   '+919840000012') returning patient_id into pid12;

  -- Patient 1: Completed 3 days ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid1, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid1, d_id, today - 3, 'completed',
      'Erythematous plaques with silvery-white scales on elbows, knees, lumbosacral. Auspitz sign positive. PASI 8.4. Nail pitting present.',
      '1. Ointment Clobetasol Propionate 0.05% + Salicylic Acid 6% - thin film BD to plaques for 14 days
2. Cream Calcipotriol 0.005% - once daily evening
3. Emollient (Liquid Paraffin + WSP) - liberally after bathing
4. Avoid skin trauma (Koebner). Phototherapy evaluation if no response in 4 weeks.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 2: Completed today
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid2, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid2, d_id, a, today, 'completed', true, r1, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid2, d_id, today, 'completed',
      '19-year-old: widespread papules, pustules, nodular cysts on cheeks, forehead, jawline with early scarring. Previous topicals ineffective. Labs normal.',
      '1. Cap Isotretinoin 20mg - once daily with fatty dinner (30 days)
2. Gel Clindamycin 1% + Nicotinamide 4% - apply morning on affected areas
3. Non-comedogenic Sunscreen SPF 50 - 20 min before outdoor exposure
4. Contraception counseling provided and documented.',
      r1, now() - interval '2 hours');

  -- Patient 3: IN CONSULTATION
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid3, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid3, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, pid3, d_id, today, 'in_progress',
      'Recurrent wheals and urticarial plaques daily over limbs and trunk for 8+ weeks, lasting 4-12 hrs. Dermographism positive. IgE 410 IU/mL.',
      '1. Tab Bilastine 20mg - once daily morning on empty stomach (30 days)
2. Tab Fexofenadine 180mg SOS evening for breakthrough itch
3. Calamine lotion with Aloe Vera topically
4. Avoid hot showers, tight clothing, NSAIDs.');

  -- Patient 4: WAITING
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid4, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid4, d_id, a, today, 'waiting', true, r1, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 5: CHECK-IN REQUESTED
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid5, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (pid5, d_id, a, today, 'checkin_requested', false);

  -- Patient 6: Confirmed + past cancelled
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today - 6, '16:00', 'cancelled');

  -- Patient 7: Completed 5 days ago
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid7, d_id, today - 5, '09:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid7, d_id, a, today - 5, 'completed', true, r1, now() - interval '5 days 4 hours', now() - interval '5 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid7, d_id, today - 5, 'completed',
      'Coin-sized hypopigmented patch on left cheek with loss of sensation, slightly raised edges. Single lesion. High suspicion Tuberculoid Leprosy (BT type).',
      '1. Rifampicin 600mg - 1 tablet monthly supervised dose
2. Dapsone 100mg - 1 tablet daily for 6 months (PB-MDT regimen)
3. Baseline G6PD, CBC, LFTs ordered. Contact tracing advised.',
      r1, now() - interval '5 days 3 hours');

  -- Patient 8: Upcoming tomorrow
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid8, d_id, today + 1, '11:00', 'confirmed');

  -- Patient 9: Walk-in waiting today
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid9, d_id, today, 'waiting', true, r1, now() - interval '9 minutes', now() - interval '9 minutes');

  -- Patient 10: Completed 1 week ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid10, d_id, today - 7, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid10, d_id, a, today - 7, 'completed', true, r1, now() - interval '7 days 4 hours', now() - interval '7 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid10, d_id, today - 7, 'completed',
      'Intense scalp itching, yellow greasy flakes, erythema at hairline, behind ears, nasolabial folds. Dx: Seborrhoeic Dermatitis.',
      '1. Shampoo Ketoconazole 2% - lather, leave 5 min, twice weekly for 4 weeks
2. Lotion Fluocinolone Acetonide 0.01% in Coconut Oil - apply to scalp overnight twice weekly
3. Urea 10% cream for nasolabial and retroauricular areas daily.',
      r1, now() - interval '7 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid10, d_id, today + 14, '10:00', 'confirmed');

  -- Patient 11: Upcoming in 2 days
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid11, d_id, today + 2, '14:00', 'confirmed');

  -- Patient 12: Completed 2 weeks ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid12, d_id, today - 14, '10:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid12, d_id, a, today - 14, 'completed', true, r1, now() - interval '14 days 4 hours', now() - interval '14 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid12, d_id, today - 14, 'completed',
      '35-year-old woman: bilateral hyperpigmented patches cheeks, upper lip, forehead (melasma). Worse on sun. On OCP. Woods lamp: epidermal pattern.',
      '1. Cream Tretinoin 0.025% + Hydroquinone 4% + Mometasone 0.1% (triple combo) - thin film at night for 12 weeks
2. Mineral Sunscreen SPF 50+ PA++++ - every 2 hours outdoors
3. Consider alternative contraception. Glycolic acid peel 30% scheduled in 4 weeks.',
      r1, now() - interval '14 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid12, d_id, today + 28, '10:00', 'confirmed');

  -- =========================================================================
  -- DOCTOR 5: Dr. Rajesh Kulkarni (Orthopedic Surgeon)
  -- =========================================================================
  select doctor_id into d_id from public.doctors where user_id = '11111111-1111-1111-1111-000000000005';

  insert into public.patients(name, phone) values ('Bhaskar Murthy',     '+919850000001') returning patient_id into pid1;
  insert into public.patients(name, phone) values ('Leela Krishnan',     '+919850000002') returning patient_id into pid2;
  insert into public.patients(name, phone) values ('Pradeep Kadam',      '+919850000003') returning patient_id into pid3;
  insert into public.patients(name, phone) values ('Vandana Prabhu',     '+919850000004') returning patient_id into pid4;
  insert into public.patients(name, phone) values ('Chetan Shrestha',    '+919850000005') returning patient_id into pid5;
  insert into public.patients(name, phone) values ('Girish Mahajan',     '+919850000006') returning patient_id into pid6;
  insert into public.patients(name, phone) values ('Subramanian Pillai', '+919850000007') returning patient_id into pid7;
  insert into public.patients(name, phone) values ('Kamala Devi',        '+919850000008') returning patient_id into pid8;
  insert into public.patients(name, phone) values ('Arvind Sharma',      '+919850000009') returning patient_id into pid9;
  insert into public.patients(name, phone) values ('Nirmala Singh',      '+919850000010') returning patient_id into pid10;
  insert into public.patients(name, phone) values ('Dinesh Gawde',       '+919850000011') returning patient_id into pid11;
  insert into public.patients(name, phone) values ('Usha Joshi',         '+919850000012') returning patient_id into pid12;
  insert into public.patients(name, phone) values ('Ramakrishna Rao',    '+919850000013') returning patient_id into pid13;

  -- Patient 1: Completed 3 days ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today - 3, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid1, d_id, a, today - 3, 'completed', true, r1, now() - interval '3 days 4 hours', now() - interval '3 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid1, d_id, today - 3, 'completed',
      '62-year-old: bilateral medial knee pain, morning stiffness 25 min, difficulty climbing stairs. Crepitus, medial joint line tenderness, effusion right knee. X-ray: medial joint space narrowing, sclerosis, osteophytes.',
      '1. Tab Diacerein 50mg + Glucosamine 750mg - 1 tablet twice daily after meals (60 days)
2. Tab Aceclofenac 100mg + Paracetamol 325mg - SOS after meals for flares
3. Gel Diclofenac 1.16% - apply locally thrice daily
4. Quadriceps/hamstring exercises under physio guidance. Weight loss target 5 kg.',
      r1, now() - interval '3 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid1, d_id, today + 10, '10:30', 'confirmed');

  -- Patient 2: Completed today
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid2, d_id, today, '08:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid2, d_id, a, today, 'completed', true, r1, now() - interval '2 hours 30 minutes', now() - interval '2 hours 30 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid2, d_id, today, 'completed',
      'Sharp shooting lower back pain radiating down left posterolateral thigh into dorsum of foot. Left SLR positive at 40 deg. EHL weakness grade 4/5. MRI: L4-L5 disc herniation with left nerve root compression.',
      '1. Tab Pregabalin 75mg - 1 capsule twice daily (30 days)
2. Tab Aceclofenac 200mg SR - once daily after dinner (10 days)
3. Tab Thiocolchicoside 4mg - 1 tablet twice daily for 5 days
4. Lumbo-sacral support belt. Avoid forward bending/heavy lifting. Core physio.',
      r1, now() - interval '2 hours');

  -- Patient 3: IN CONSULTATION
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid3, d_id, today, '09:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid3, d_id, a, today, 'in_consultation', true, r1, now() - interval '20 minutes', now() - interval '20 minutes') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription)
    values (q, a, pid3, d_id, today, 'in_progress',
      'Severe nocturnal shoulder pain, progressive restriction active and passive motion over 3 months. Abduction 70 deg, external rotation 15 deg. Rotator cuff intact on USS. Frozen shoulder (Adhesive Capsulitis).',
      '1. Intra-articular Methylprednisolone 40mg + 2% Lignocaine administered
2. Tab Tramadol 37.5mg + Paracetamol 325mg - SOS at bedtime for severe night pain
3. Tab Deflazacort 6mg - once daily for 5 days
4. Supervised physio: Codman''s pendulum, wall climbing, overhead pulley mobilization.');

  -- Patient 4: WAITING
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid4, d_id, today, '10:00', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid4, d_id, a, today, 'waiting', true, r1, now() - interval '15 minutes', now() - interval '15 minutes');

  -- Patient 5: CHECK-IN REQUESTED
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid5, d_id, today, '10:30', 'checked_in') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified)
    values (pid5, d_id, a, today, 'checkin_requested', false);

  -- Patient 6: Confirmed + past cancelled
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today, '15:00', 'confirmed');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid6, d_id, today - 6, '16:00', 'cancelled');

  -- Patient 7: Completed 5 days ago
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid7, d_id, today - 5, '09:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid7, d_id, a, today - 5, 'completed', true, r1, now() - interval '5 days 4 hours', now() - interval '5 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid7, d_id, today - 5, 'completed',
      '55-year-old: acute right wrist pain after fall on outstretched hand. X-ray: transverse distal radius fracture with dorsal angulation 15 deg (Colles'' Fracture). Neurovascular intact.',
      '1. Closed reduction under haematoma block with Lignocaine 2%
2. POP back slab applied with padding for 3 weeks
3. Elevate limb above heart level 48 hours. Active finger exercises from Day 1.
4. Review in 3 weeks for full POP and repeat X-ray.',
      r1, now() - interval '5 days 3 hours');

  -- Patient 8: Upcoming tomorrow
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid8, d_id, today + 1, '14:00', 'confirmed');

  -- Patient 9: Walk-in waiting today
  insert into public.queue_entries(patient_id, doctor_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid9, d_id, today, 'waiting', true, r1, now() - interval '6 minutes', now() - interval '6 minutes');

  -- Patient 10: Completed 1 week ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid10, d_id, today - 7, '09:30', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid10, d_id, a, today - 7, 'completed', true, r1, now() - interval '7 days 4 hours', now() - interval '7 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid10, d_id, today - 7, 'completed',
      'Post-op review: left total knee replacement 6 weeks ago. Wound healed. Flexion 90 deg, extension lag 5 deg. Implant satisfactory on X-ray. Mild peri-patellar tenderness.',
      '1. Tab Celecoxib 200mg - once daily after food for 2 weeks
2. Continue physio: stair climbing, stationary cycling, swimming
3. No high-impact sports. Review at 3 months with standing X-ray.',
      r1, now() - interval '7 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid10, d_id, today + 21, '09:00', 'confirmed');

  -- Patient 11: Upcoming in 3 days
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid11, d_id, today + 3, '11:00', 'confirmed');

  -- Patient 12: Completed 2 weeks ago + upcoming
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid12, d_id, today - 14, '10:00', 'completed') returning appointment_id into a;
  insert into public.queue_entries(patient_id, doctor_id, appointment_id, queue_date, status, verified, verified_by, verified_at, queued_at)
    values (pid12, d_id, a, today - 14, 'completed', true, r1, now() - interval '14 days 4 hours', now() - interval '14 days 4 hours') returning queue_id into q;
  insert into public.consultations(queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_by, verified_at)
    values (q, a, pid12, d_id, today - 14, 'completed',
      '72-year-old: progressive right hip pain 2 years, radiating to groin. Limping, restricted internal rotation. X-ray: superior joint space narrowing, subchondral cysts. End-stage OA right hip.',
      '1. Tab Tramadol 50mg - BD SOS for severe pain
2. Tab Paracetamol 650mg MR - 1 tablet TID with food
3. Walking stick (contralateral hand). Hip-strengthening physio.
4. Right Total Hip Replacement planned. Pre-anaesthetic evaluation ordered.',
      r1, now() - interval '14 days 3 hours');
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid12, d_id, today + 14, '09:30', 'confirmed');

  -- Patient 13: Upcoming in 5 days
  insert into public.appointments(patient_id, doctor_id, appointment_date, appointment_time, status)
    values (pid13, d_id, today + 5, '14:00', 'confirmed');

  -- =========================================================================
  -- 3.7 Recalculate queue positions for today across all 5 doctors
  -- =========================================================================
  for doc_rec in select doctor_id from public.doctors loop
    perform public.recalculate_queue(doc_rec.doctor_id, today);
  end loop;
end $$;
