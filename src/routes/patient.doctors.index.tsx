import { useMemo, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { listDoctors } from "@/shared/repositories";
import { useAsync } from "@/shared/hooks";
import { AsyncView, EmptyState, PageHeader } from "@/shared/ui";

export const Route = createFileRoute("/patient/doctors/")({
  head: () => ({
    meta: [
      { title: "Find a doctor — SMAQMS" },
      { name: "description", content: "Find a clinic doctor and choose your next appointment." },
      { property: "og:title", content: "Find a doctor — SMAQMS" },
      {
        property: "og:description",
        content: "Find a clinic doctor and choose your next appointment.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: SearchDoctor,
});

function SearchDoctor() {
  const state = useAsync(listDoctors, []);
  const [q, setQ] = useState("");
  const [spec, setSpec] = useState("all");
  const specs = useMemo(
    () => Array.from(new Set((state.data ?? []).map((d) => d.specialization))),
    [state.data],
  );
  const filtered = (state.data ?? []).filter(
    (d) =>
      (spec === "all" || d.specialization === spec) &&
      `${d.name} ${d.specialization}`.toLowerCase().includes(q.toLowerCase().trim()),
  );

  return (
    <>
      <PageHeader title="Your next appointment" subtitle="Find the right doctor for your visit." />
      <div className="mb-6 flex flex-col gap-3 sm:flex-row">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search doctors…"
            className="pl-9"
          />
        </div>
        <div className="flex flex-wrap gap-2">
          {["all", ...specs].map((s) => (
            <Button
              key={s}
              size="sm"
              variant={spec === s ? "default" : "outline"}
              onClick={() => setSpec(s)}
              className="capitalize"
            >
              {s}
            </Button>
          ))}
        </div>
      </div>
      <AsyncView
        state={state}
        isEmpty={() => filtered.length === 0}
        empty={<EmptyState title="No doctors match" hint="Try a different search." />}
      >
        {() => (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {filtered.map((d) => (
              <div
                key={d.doctorId}
                className="flex flex-col rounded-lg border bg-card p-6 transition-colors hover:border-primary/50"
              >
                <div className="mb-4 flex items-center gap-3">
                  <span className="grid size-12 place-items-center rounded-full bg-muted text-sm font-bold text-primary">
                    {d.name
                      .replace("Dr. ", "")
                      .split(" ")
                      .map((p) => p[0])
                      .join("")}
                  </span>
                  <div>
                    <p className="font-semibold text-foreground">{d.name}</p>
                    <p className="text-sm text-muted-foreground">{d.specialization}</p>
                  </div>
                </div>
                <p className="mb-5 border-t pt-4 text-xs text-muted-foreground">
                  {d.slotMinutes}-minute slots · Mon–Sat
                </p>
                <div className="mt-auto flex gap-2">
                  <Button variant="outline" size="sm" className="flex-1" asChild>
                    <Link to="/patient/doctors/$doctorId" params={{ doctorId: String(d.doctorId) }}>
                      View availability
                    </Link>
                  </Button>
                  <Button size="sm" className="flex-1" asChild>
                    <Link to="/patient/book" search={{ doctorId: d.doctorId }}>
                      Book
                    </Link>
                  </Button>
                </div>
              </div>
            ))}
          </div>
        )}
      </AsyncView>
    </>
  );
}
