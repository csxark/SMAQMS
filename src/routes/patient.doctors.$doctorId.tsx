import { createFileRoute, Link } from "@tanstack/react-router";
import { Button } from "@/components/ui/button";
import { getAvailableSlots, getDoctor } from "@/shared/repositories";
import { useAsync } from "@/shared/hooks";
import { AsyncView, EmptyState, PageHeader } from "@/shared/ui";
import { addDays, clinicToday, DAY_NAMES, formatDate, formatTime } from "@/shared/clinic";

export const Route = createFileRoute("/patient/doctors/$doctorId")({
  head: () => ({ meta: [{"title": "Doctor availability — SMAQMS"}, {"name": "description", "content": "View clinic doctor hours and available appointment slots."}, {"property": "og:title", "content": "Doctor availability — SMAQMS"}, {"property": "og:description", "content": "View clinic doctor hours and available appointment slots."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  component: Availability,
});

function Availability() {
  const id = Number(Route.useParams().doctorId);
  const state = useAsync(async () => {
    const doctor = await getDoctor(id);
    const today = clinicToday();
    const days = await Promise.all(
      Array.from({ length: 7 }, (_, i) => addDays(today, i)).map(async (date) => {
        const slots = await getAvailableSlots(id, date);
        return { date, open: slots.filter((s) => s.available).length, total: slots.length };
      }),
    );
    return { doctor, days };
  }, [id]);

  return (
    <AsyncView state={state} empty={<EmptyState title="Doctor not found" />}>
      {({ doctor, days }) => (
        <>
          <PageHeader
            title={doctor.name}
            subtitle={doctor.specialization}
            action={<Button asChild><Link to="/patient/book" search={{ doctorId: doctor.doctorId }}>Book appointment</Link></Button>}
          />
          <div className="grid gap-6 lg:grid-cols-2">
            <section className="rounded-2xl border bg-card p-5">
              <h2 className="mb-4 text-xl font-semibold">Weekly hours</h2>
              <ul className="divide-y">
                {DAY_NAMES.map((name, dow) => {
                  const w = doctor.availability.filter((a) => a.dayOfWeek === dow);
                  return (
                    <li key={name} className="flex justify-between py-2 text-sm">
                      <span className="font-medium text-foreground">{name}</span>
                      <span className="text-muted-foreground">
                        {w.length ? w.map((x) => `${formatTime(x.start)}–${formatTime(x.end)}`).join(", ") : "Closed"}
                      </span>
                    </li>
                  );
                })}
              </ul>
            </section>
            <section className="rounded-2xl border bg-card p-5">
              <h2 className="mb-4 text-xl font-semibold">Next 7 days</h2>
              <ul className="space-y-2">
                {days.map((d) => (
                  <li key={d.date} className="flex items-center justify-between rounded-xl bg-muted/60 px-4 py-3 text-sm">
                    <span className="font-medium text-foreground">{formatDate(d.date)}</span>
                    <span className={d.open ? "font-semibold text-success" : "text-muted-foreground"}>
                      {d.total === 0 ? "Closed" : `${d.open} open slot${d.open === 1 ? "" : "s"}`}
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          </div>
        </>
      )}
    </AsyncView>
  );
}
