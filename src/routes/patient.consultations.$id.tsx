import { createFileRoute } from "@tanstack/react-router";
import { getConsultation } from "@/shared/repositories";
import { useAsync } from "@/shared/hooks";
import { AsyncView, EmptyState, PageHeader, StatusBadge } from "@/shared/ui";
import { formatDate } from "@/shared/clinic";

export const Route = createFileRoute("/patient/consultations/$id")({
  head: () => ({ meta: [{"title": "Consultation details — SMAQMS"}, {"name": "description", "content": "Read your verified consultation notes and prescription."}, {"property": "og:title", "content": "Consultation details — SMAQMS"}, {"property": "og:description", "content": "Read your verified consultation notes and prescription."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  component: Details,
});

function Details() {
  const id = Number(Route.useParams().id);
  const state = useAsync(() => getConsultation(id), [id]);
  return (
    <AsyncView
      state={state}
      isEmpty={(c) => c === null}
      empty={<EmptyState title="Not available yet" hint="Available after the receptionist verifies your consultation." />}
    >
      {(c) =>
        c && (
          <>
            <PageHeader title="Consultation details" subtitle={`${c.doctorName} · ${c.specialization} · ${formatDate(c.date)}`} action={<StatusBadge status={c.status} />} />
            <div className="grid gap-4 md:grid-cols-2">
              <section className="rounded-2xl border bg-card p-5">
                <h2 className="mb-2 text-xl font-semibold">Notes</h2>
                <p className="whitespace-pre-wrap text-sm text-foreground">{c.notes || "No notes recorded."}</p>
              </section>
              <section className="rounded-2xl border bg-accent/50 p-5">
                <h2 className="mb-2 text-xl font-semibold">Prescription</h2>
                <p className="whitespace-pre-wrap text-sm text-foreground">{c.prescription || "No prescription."}</p>
              </section>
            </div>
          </>
        )
      }
    </AsyncView>
  );
}
