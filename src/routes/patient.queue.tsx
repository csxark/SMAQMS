import { useRef } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { toast } from "sonner";
import { Clock, Hourglass, UserRound } from "lucide-react";
import { Button } from "@/components/ui/button";
import { myTodayQueue, type QueueEntry } from "@/shared/repositories";
import { useAsync, useRealtime } from "@/shared/hooks";
import { AsyncView, EmptyState, PageHeader, StatusBadge } from "@/shared/ui";
import { formatTime } from "@/shared/clinic";

export const Route = createFileRoute("/patient/queue")({
  head: () => ({ meta: [{"title": "My queue status — SMAQMS"}, {"name": "description", "content": "Follow your personal clinic queue and consultation status."}, {"property": "og:title", "content": "My queue status — SMAQMS"}, {"property": "og:description", "content": "Follow your personal clinic queue and consultation status."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  component: QueueStatus,
});

function QueueStatus() {
  const prev = useRef<Map<number, QueueEntry>>(new Map());
  const state = useAsync(async () => {
    const rows = await myTodayQueue();
    for (const r of rows) {
      const old = prev.current.get(r.queueId);
      if (old && old.status !== r.status) {
        if (r.status === "waiting") toast.success(`Added to the queue (position #${r.position ?? "?"})`);
        else toast.info("Queue updated");
      } else if (old && old.position !== r.position && r.position) toast.info("Queue updated");
    }
    prev.current = new Map(rows.map((r) => [r.queueId, r]));
    return rows;
  }, []);
  useRealtime(["queue_entries", "consultations"], () => void state.reload(true));

  return (
    <>
      <PageHeader title="My queue status" subtitle="Updates live as reception and your doctor move the line." />
      <AsyncView
        state={state}
        isEmpty={(d) => d.length === 0}
        empty={<EmptyState title="You're not in today's queue" hint="Check in from your appointments on the day of your visit." action={<Button asChild><Link to="/patient/appointments">My appointments</Link></Button>} />}
      >
        {(rows) => (
          <div className="space-y-4">
            {rows.map((q) => (
              <div key={q.queueId} className="overflow-hidden rounded-3xl border bg-card shadow-soft">
                <div className="bg-hero p-6">
                  <div className="flex items-center justify-between">
                    <StatusBadge status={q.status} />
                    {q.appointmentTime && <span className="flex items-center gap-1 text-sm text-accent-foreground"><Clock className="size-4" /> {formatTime(q.appointmentTime)}</span>}
                  </div>
                  <p className="mt-6 text-3xl font-semibold leading-tight text-foreground sm:text-5xl">
                    {q.status === "waiting" && q.position ? `You are #${q.position} in line` :
                     q.status === "checkin_requested" ? "Waiting for verification" :
                     q.status === "in_consultation" ? "You're with the doctor" :
                     q.status === "completed" ? "Visit complete" : "Cancelled"}
                  </p>
                </div>
                <div className="flex flex-wrap items-center gap-4 p-5 text-sm">
                  <span className="flex items-center gap-2 text-foreground"><UserRound className="size-4 text-primary" /> {q.doctorName}</span>
                  {q.status === "checkin_requested" && (
                    <span className="flex items-center gap-2 text-muted-foreground"><Hourglass className="size-4" /> Waiting for receptionist verification</span>
                  )}
                  {q.consultation?.verifiedAt && (
                    <Button size="sm" variant="outline" className="ml-auto" asChild>
                      <Link to="/patient/consultations/$id" params={{ id: String(q.consultation.id) }}>View consultation</Link>
                    </Button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </AsyncView>
    </>
  );
}
