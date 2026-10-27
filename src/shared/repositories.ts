import { supabase } from "@/integrations/supabase/client";
import type { Database } from "@/integrations/supabase/types";
import { clinicToday } from "./clinic";

export type AppointmentStatus = Database["public"]["Enums"]["appointment_status"];
export type QueueStatus = Database["public"]["Enums"]["queue_status"];
export type ConsultationStatus = Database["public"]["Enums"]["consultation_status"];
export type AppRole = Database["public"]["Enums"]["app_role"];

function ok<T>(res: { data: T | null; error: { message: string } | null }): T {
  if (res.error) throw new Error(res.error.message);
  if (res.data === null) throw new Error("NOT_FOUND: Not found");
  return res.data;
}

const t = (s: string) => s.slice(0, 5);

/* Doctors */
export async function listDoctors() {
  const rows = ok(
    await supabase
      .from("doctors")
      .select(
        "doctor_id, name, specialization, slot_minutes, doctor_availability(day_of_week, start_time, end_time)",
      )
      .order("name"),
  );
  return rows.map((d) => ({
    doctorId: d.doctor_id,
    name: d.name,
    specialization: d.specialization,
    slotMinutes: d.slot_minutes,
    availability: d.doctor_availability
      .map((a) => ({ dayOfWeek: a.day_of_week, start: t(a.start_time), end: t(a.end_time) }))
      .sort((a, b) => a.dayOfWeek - b.dayOfWeek || a.start.localeCompare(b.start)),
  }));
}
export type Doctor = Awaited<ReturnType<typeof listDoctors>>[number];

export async function getDoctor(id: number) {
  const all = await listDoctors();
  const d = all.find((x) => x.doctorId === id);
  if (!d) throw new Error("NOT_FOUND: Doctor not found");
  return d;
}

export async function getAvailableSlots(doctorId: number, date: string) {
  const rows = ok(
    await supabase.rpc("get_available_slots", { p_doctor_id: doctorId, p_date: date }),
  );
  return rows.map((r) => ({ time: t(r.slot_time), available: r.is_available }));
}

/* Appointments */
const APPT =
  "appointment_id, appointment_date, appointment_time, status, patient_id, doctor_id, doctors(name, specialization), patients(name, phone)";
function mapAppt(a: {
  appointment_id: number;
  appointment_date: string;
  appointment_time: string;
  status: AppointmentStatus;
  patient_id: number;
  doctor_id: number;
  doctors: { name: string; specialization: string } | null;
  patients: { name: string; phone: string } | null;
}) {
  return {
    appointmentId: a.appointment_id,
    date: a.appointment_date,
    time: t(a.appointment_time),
    status: a.status,
    patientId: a.patient_id,
    doctorId: a.doctor_id,
    doctorName: a.doctors?.name ?? "Doctor",
    specialization: a.doctors?.specialization ?? "",
    patientName: a.patients?.name ?? "Patient",
    patientPhone: a.patients?.phone ?? "",
  };
}
export type Appointment = ReturnType<typeof mapAppt>;

export async function myAppointments() {
  const pid = ok(await supabase.rpc("current_patient_id"));
  const rows = ok(
    await supabase
      .from("appointments")
      .select(APPT)
      .eq("patient_id", pid)
      .order("appointment_date", { ascending: false })
      .order("appointment_time", { ascending: false }),
  );
  return rows.map(mapAppt);
}

export async function todaysAppointments(status?: AppointmentStatus) {
  let q = supabase.from("appointments").select(APPT).eq("appointment_date", clinicToday());
  if (status) q = q.eq("status", status);
  return ok(await q.order("appointment_time")).map(mapAppt);
}

/* Queue */
const QUEUE =
  "queue_id, patient_id, doctor_id, appointment_id, queue_date, queue_position, status, verified, queued_at, created_at, doctors(name), patients(name, phone), appointments(appointment_time), consultations(consultation_id, status, verified_at)";
function mapQueue(q: {
  queue_id: number;
  patient_id: number;
  doctor_id: number;
  appointment_id: number | null;
  queue_date: string;
  queue_position: number | null;
  status: QueueStatus;
  verified: boolean;
  queued_at: string | null;
  created_at: string;
  doctors: { name: string } | null;
  patients: { name: string; phone: string } | null;
  appointments: { appointment_time: string } | null;
  consultations: {
    consultation_id: number;
    status: ConsultationStatus;
    verified_at: string | null;
  } | null;
}) {
  return {
    queueId: q.queue_id,
    patientId: q.patient_id,
    doctorId: q.doctor_id,
    appointmentId: q.appointment_id,
    queueDate: q.queue_date,
    position: q.queue_position,
    status: q.status,
    verified: q.verified,
    createdAt: q.created_at,
    doctorName: q.doctors?.name ?? "Doctor",
    patientName: q.patients?.name ?? "Patient",
    patientPhone: q.patients?.phone ?? "",
    appointmentTime: q.appointments ? t(q.appointments.appointment_time) : null,
    consultation: q.consultations
      ? {
          id: q.consultations.consultation_id,
          status: q.consultations.status,
          verifiedAt: q.consultations.verified_at,
        }
      : null,
  };
}
export type QueueEntry = ReturnType<typeof mapQueue>;

export async function todaysQueue() {
  const rows = ok(
    await supabase
      .from("queue_entries")
      .select(QUEUE)
      .eq("queue_date", clinicToday())
      .order("queue_position", { ascending: true, nullsFirst: false })
      .order("created_at"),
  );
  return rows.map(mapQueue);
}

export async function myTodayQueue() {
  const pid = ok(await supabase.rpc("current_patient_id"));
  const rows = ok(
    await supabase
      .from("queue_entries")
      .select(QUEUE)
      .eq("patient_id", pid)
      .eq("queue_date", clinicToday())
      .order("created_at", { ascending: false }),
  );
  return rows.map(mapQueue);
}

/* Consultations */
const CONS =
  "consultation_id, queue_id, appointment_id, patient_id, doctor_id, consultation_date, status, notes, prescription, verified_at, doctors(name, specialization), patients(name, phone, email)";
function mapCons(c: {
  consultation_id: number;
  queue_id: number;
  appointment_id: number | null;
  patient_id: number;
  doctor_id: number;
  consultation_date: string;
  status: ConsultationStatus;
  notes: string;
  prescription: string;
  verified_at: string | null;
  doctors: { name: string; specialization: string } | null;
  patients: { name: string; phone: string; email: string | null } | null;
}) {
  return {
    consultationId: c.consultation_id,
    queueId: c.queue_id,
    appointmentId: c.appointment_id,
    patientId: c.patient_id,
    doctorId: c.doctor_id,
    date: c.consultation_date,
    status: c.status,
    notes: c.notes,
    prescription: c.prescription,
    verifiedAt: c.verified_at,
    doctorName: c.doctors?.name ?? "Doctor",
    specialization: c.doctors?.specialization ?? "",
    patientName: c.patients?.name ?? "Patient",
    patientPhone: c.patients?.phone ?? "",
    patientEmail: c.patients?.email ?? null,
  };
}
export type Consultation = ReturnType<typeof mapCons>;

export async function getConsultation(id: number) {
  const r = await supabase
    .from("consultations")
    .select(CONS)
    .eq("consultation_id", id)
    .maybeSingle();
  if (r.error) throw new Error(r.error.message);
  return r.data ? mapCons(r.data) : null;
}

export async function getConsultationByAppointment(appointmentId: number) {
  const r = await supabase
    .from("consultations")
    .select("consultation_id, verified_at")
    .eq("appointment_id", appointmentId)
    .maybeSingle();
  if (r.error) throw new Error(r.error.message);
  return r.data;
}

export async function listConsultations() {
  const rows = ok(
    await supabase
      .from("consultations")
      .select(CONS)
      .order("created_at", { ascending: false })
      .limit(100),
  );
  return rows.map(mapCons);
}

/* Public queue board (landing page, no sign-in required, no patient data) */
export async function publicQueueBoard() {
  const rows = ok(await supabase.rpc("public_queue_board"));
  return rows.map((r) => ({
    doctorId: r.doctor_id,
    doctorName: r.doctor_name,
    specialization: r.specialization,
    nowServing: r.now_serving,
    waitingCount: r.waiting_count,
  }));
}
export type QueueBoardRow = Awaited<ReturnType<typeof publicQueueBoard>>[number];
