import { supabase } from "@/integrations/supabase/client";
import type { ConsultationStatus, QueueStatus } from "./repositories";

function check<T>(res: { data: T; error: { message: string } | null }): T {
  if (res.error) throw new Error(res.error.message);
  return res.data;
}

export const rpc = {
  bookAppointment: async (doctorId: number, date: string, time: string) =>
    check(
      await supabase.rpc("book_appointment", { p_doctor_id: doctorId, p_date: date, p_time: time }),
    ),
  cancelAppointment: async (id: number) =>
    check(await supabase.rpc("cancel_appointment", { p_appointment_id: id })),
  requestCheckIn: async (id: number) =>
    check(await supabase.rpc("request_check_in", { p_appointment_id: id })),
  receptionistCheckIn: async (id: number) =>
    check(await supabase.rpc("receptionist_check_in_patient", { p_appointment_id: id })),
  verifyAndAddToQueue: async (queueId: number) =>
    check(await supabase.rpc("verify_and_add_to_queue", { p_queue_id: queueId })),
  registerWalkIn: async (name: string, phone: string, email: string | null, doctorId: number) =>
    check(
      await supabase.rpc("register_walk_in_patient", {
        p_name: name,
        p_phone: phone,
        p_email: email ?? "",
        p_doctor_id: doctorId,
      }),
    ),
  updateQueueStatus: async (queueId: number, status: QueueStatus) =>
    check(await supabase.rpc("update_queue_status", { p_queue_id: queueId, p_status: status })),
  startConsultation: async (queueId: number) =>
    check(await supabase.rpc("start_consultation", { p_queue_id: queueId })),
  updateConsultationStatus: async (id: number, status: ConsultationStatus) =>
    check(
      await supabase.rpc("update_consultation_status", { p_consultation_id: id, p_status: status }),
    ),
  saveNotes: async (id: number, notes: string) =>
    check(await supabase.rpc("save_consultation_notes", { p_consultation_id: id, p_notes: notes })),
  savePrescription: async (id: number, text: string) =>
    check(await supabase.rpc("save_prescription", { p_consultation_id: id, p_prescription: text })),
  verifyConsultation: async (id: number) =>
    check(await supabase.rpc("verify_consultation_status", { p_consultation_id: id })),
};
