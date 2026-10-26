import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { todaysQueue } from "@/shared/repositories";
import { rpc } from "@/shared/rpc";
import { useAsync, useRealtime } from "@/shared/hooks";
import { AsyncView, EmptyState, PageHeader, StatusBadge } from "@/shared/ui";
import { formatTime } from "@/shared/clinic";
import { friendlyError } from "@/shared/errors";

export const Route = createFileRoute("/doctor/queue")({
  head: () => ({ meta: [{"title": "Patient queue — SMAQMS"}, {"name": "description", "content": "Manage your verified patient queue and open consultations."}, {"property": "og:title", "content": "Patient queue — SMAQMS"}, {"property": "og:description", "content": "Manage your verified patient queue and open consultations."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  component: DoctorQueue,
});

function DoctorQueue() {
  const state = useAsync(todaysQueue, []);
  useRealtime(["queue_entries", "consultations"], () => void state.reload(true));
  const navigate = useNavigate();
  const rows = (state.data ?? []).filter((q) => q.status !== "cancelled" && q.status !== "checkin_requested");
  const active = rows.find((q) => q.status === "in_consultation");

  return (
    <>
      <PageHeader title="Patient queue" subtitle="Patients verified by reception, in order." />
      <AsyncView state={state} isEmpty={() => rows.length === 0} empty={<EmptyState title="Queue is empty" hint="Verified patients will appear here." />}>
        {() => (
          <ul className="space-y-3">
            {rows.map((q) => (
              <li key={q.queueId} className="flex flex-wrap items-center gap-4 rounded-lg border bg-card p-4">
                <span className="grid size-12 shrink-0 place-items-center rounded-xl bg-accent font-display text-xl font-semibold text-accent-foreground">
                  {q.position ?? "·"}
                </span>
                <div className="min-w-36 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-semibold text-foreground">{q.patientName}</p>
                    <StatusBadge status={q.status} />
                  </div>
                  <p className="text-sm text-muted-foreground">{q.appointmentTime ? `Appointment ${formatTime(q.appointmentTime)}` : "Walk-in"}</p>
                </div>
                {q.status === "waiting" && (
                  <TooltipProvider>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <span>
                          <Button size="sm" disabled={!!active} onClick={async () => {
                            try { const id = await rpc.startConsultation(q.queueId); toast.success("Consultation started"); void navigate({ to: "/doctor/consultations/$id", params: { id: String(id) } }); }
                            catch (e) { toast.error(friendlyError(e)); }
                          }}>Start consultation</Button>
                        </span>
                      </TooltipTrigger>
                      {active && <TooltipContent>Finish your current consultation first</TooltipContent>}
                    </Tooltip>
                  </TooltipProvider>
                )}
                {q.consultation && (
                  <Button size="sm" variant="outline" asChild>
                    <Link to="/doctor/consultations/$id" params={{ id: String(q.consultation.id) }}>Open</Link>
                  </Button>
                )}
              </li>
            ))}
          </ul>
        )}
      </AsyncView>
    </>
  );
}
