import { useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { myAppointments, getConsultationByAppointment, type AppointmentStatus } from "@/shared/repositories";
import { rpc } from "@/shared/rpc";
import { useAsync, useRealtime } from "@/shared/hooks";
import { AsyncView, EmptyState, PageHeader, StatusBadge } from "@/shared/ui";
import { ConfirmButton } from "@/shared/Confirm";
import { clinicToday, formatDate, formatTime } from "@/shared/clinic";
import { friendlyError } from "@/shared/errors";

export const Route = createFileRoute("/patient/appointments")({
  head: () => ({ meta: [{"title": "My appointments — SMAQMS"}, {"name": "description", "content": "View your clinic appointments and check in for your visit."}, {"property": "og:title", "content": "My appointments — SMAQMS"}, {"property": "og:description", "content": "View your clinic appointments and check in for your visit."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  component: History,
});

const FILTERS: ("all" | AppointmentStatus)[] = ["all", "confirmed", "checked_in", "completed", "cancelled"];

function History() {
  const state = useAsync(myAppointments, []);
  useRealtime(["appointments"], () => void state.reload(true));
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>("all");
  const navigate = useNavigate();
  const today = clinicToday();
  const rows = (state.data ?? []).filter((a) => filter === "all" || a.status === filter);

  const openConsultation = async (appointmentId: number) => {
    try {
      const c = await getConsultationByAppointment(appointmentId);
      if (!c) return void toast.info("Available after the receptionist verifies your consultation.");
      void navigate({ to: "/patient/consultations/$id", params: { id: String(c.consultation_id) } });
    } catch (e) { toast.error(friendlyError(e)); }
  };

  return (
    <>
      <PageHeader title="Appointment history" action={<Button asChild><Link to="/patient/book" search={{ doctorId: undefined }}>New booking</Link></Button>} />
      <div className="mb-5 flex flex-wrap gap-2">
        {FILTERS.map((f) => (
          <Button key={f} size="sm" variant={filter === f ? "default" : "outline"} onClick={() => setFilter(f)} className="capitalize">
            {f.replace("_", " ")}
          </Button>
        ))}
      </div>
      <AsyncView
        state={state}
        isEmpty={() => rows.length === 0}
        empty={<EmptyState title="No appointments here" hint="Book a slot with one of our doctors." action={<Button asChild><Link to="/patient/doctors">Find a doctor</Link></Button>} />}
      >
        {() => (
          <ul className="space-y-3">
            {rows.map((a) => (
              <li key={a.appointmentId} className="flex flex-col gap-3 rounded-2xl border bg-card p-4 sm:flex-row sm:items-center">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <p className="font-semibold text-foreground">{a.doctorName}</p>
                    <StatusBadge status={a.status} />
                  </div>
                  <p className="text-sm text-muted-foreground">
                    {a.specialization} · {formatDate(a.date)} at {formatTime(a.time)}
                  </p>
                </div>
                <div className="flex gap-2">
                  {a.status === "confirmed" && a.date === today && (
                    <Button size="sm" onClick={async () => {
                      try { await rpc.requestCheckIn(a.appointmentId); toast.success("Check-in request sent to reception"); void navigate({ to: "/patient/queue" }); }
                      catch (e) { toast.error(friendlyError(e)); }
                    }}>Check in</Button>
                  )}
                  {(a.status === "booked" || a.status === "confirmed") && (
                    <ConfirmButton
                      size="sm" variant="outline" title="Cancel this appointment?" confirmLabel="Cancel appointment"
                      description={`${a.doctorName} on ${formatDate(a.date)} at ${formatTime(a.time)}.`}
                      onConfirm={async () => {
                        try { await rpc.cancelAppointment(a.appointmentId); toast.success("Appointment cancelled"); await state.reload(true); }
                        catch (e) { toast.error(friendlyError(e)); }
                      }}
                    >Cancel</ConfirmButton>
                  )}
                  {a.status === "completed" && (
                    <Button size="sm" variant="outline" onClick={() => openConsultation(a.appointmentId)}>View consultation</Button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
      </AsyncView>
    </>
  );
}
