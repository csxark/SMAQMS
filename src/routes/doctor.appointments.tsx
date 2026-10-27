import { createFileRoute } from "@tanstack/react-router";
import { CheckCircle2 } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { todaysAppointments } from "@/shared/repositories";
import { useAsync, useRealtime } from "@/shared/hooks";
import { AsyncView, EmptyState, PageHeader, StatusBadge } from "@/shared/ui";
import { clinicToday, formatDate, formatTime } from "@/shared/clinic";

export const Route = createFileRoute("/doctor/appointments")({
  head: () => ({
    meta: [
      { title: "Today's appointments — SMAQMS" },
      { name: "description", content: "View today’s clinic appointments and patient check-ins." },
      { property: "og:title", content: "Today's appointments — SMAQMS" },
      {
        property: "og:description",
        content: "View today’s clinic appointments and patient check-ins.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Today,
});

function Today() {
  const state = useAsync(() => todaysAppointments(), []);
  useRealtime(["appointments", "queue_entries"], () => void state.reload(true));
  return (
    <>
      <PageHeader title="Today's appointments" subtitle={formatDate(clinicToday())} />
      <AsyncView
        state={state}
        isEmpty={(d) => d.length === 0}
        empty={<EmptyState title="No appointments today" />}
      >
        {(rows) => (
          <div className="rounded-2xl border bg-card">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Time</TableHead>
                  <TableHead>Patient</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Checked in</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((a) => (
                  <TableRow key={a.appointmentId}>
                    <TableCell className="font-semibold">{formatTime(a.time)}</TableCell>
                    <TableCell>{a.patientName}</TableCell>
                    <TableCell>
                      <StatusBadge status={a.status} />
                    </TableCell>
                    <TableCell>
                      {a.status === "checked_in" || a.status === "completed" ? (
                        <CheckCircle2 className="size-5 text-success" />
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </AsyncView>
    </>
  );
}
