import { useEffect, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { toast } from "sonner";
import { Lock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { getConsultation } from "@/shared/repositories";
import { rpc } from "@/shared/rpc";
import { useAsync, useRealtime } from "@/shared/hooks";
import { AsyncView, EmptyState, PageHeader, StatusBadge } from "@/shared/ui";
import { ConfirmButton } from "@/shared/Confirm";
import { formatDate } from "@/shared/clinic";
import { friendlyError } from "@/shared/errors";

export const Route = createFileRoute("/doctor/consultations/$id")({
  head: () => ({ meta: [{"title": "Consultation — SMAQMS"}, {"name": "description", "content": "Record patient consultation notes and prescriptions."}, {"property": "og:title", "content": "Consultation — SMAQMS"}, {"property": "og:description", "content": "Record patient consultation notes and prescriptions."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  component: Workspace,
});

function Workspace() {
  const id = Number(Route.useParams().id);
  const state = useAsync(() => getConsultation(id), [id]);
  useRealtime(["consultations"], (c) => { if (!c || c.new["consultation_id"] === id) void state.reload(true); });

  return (
    <AsyncView state={state} isEmpty={(c) => c === null} empty={<EmptyState title="Consultation not found" />}>
      {(c) => c && (
        <>
          <PageHeader
            title={c.patientName}
            subtitle={`${c.patientPhone}${c.patientEmail ? ` · ${c.patientEmail}` : ""} · ${formatDate(c.date)}`}
            action={<div className="flex items-center gap-2"><StatusBadge status={c.status} />{c.verifiedAt && <span className="flex items-center gap-1 text-xs text-muted-foreground"><Lock className="size-3" /> Verified</span>}</div>}
          />
          <div className="grid gap-4 md:grid-cols-2">
            <Editor label="Consultation notes" initial={c.notes} locked={!!c.verifiedAt} save={(v) => rpc.saveNotes(c.consultationId, v)} saveLabel="Save notes" />
            <Editor label="Prescription" initial={c.prescription} locked={!!c.verifiedAt} save={(v) => rpc.savePrescription(c.consultationId, v)} saveLabel="Save prescription" />
          </div>
          <div className="mt-6 flex flex-wrap gap-2">
            <Button variant="ghost" asChild><Link to="/doctor/queue">← Back to queue</Link></Button>
            {c.status === "in_progress" && (
              <ConfirmButton
                className="ml-auto" title="Mark consultation as completed?" confirmLabel="Mark as completed"
                description="Reception will be notified to verify. You can still edit notes until they verify."
                onConfirm={async () => {
                  try { await rpc.updateConsultationStatus(c.consultationId, "completed"); toast.success("Consultation completed"); await state.reload(true); }
                  catch (e) { toast.error(friendlyError(e)); }
                }}
              >Mark as completed</ConfirmButton>
            )}
          </div>
        </>
      )}
    </AsyncView>
  );
}

function Editor({ label, initial, locked, save, saveLabel }: { label: string; initial: string; locked: boolean; save: (v: string) => Promise<unknown>; saveLabel: string }) {
  const [value, setValue] = useState(initial);
  const [busy, setBusy] = useState(false);
  useEffect(() => setValue(initial), [initial]);
  const tooLong = value.length > 5000;
  return (
    <section className="rounded-2xl border bg-card p-5">
      <h2 className="mb-3 text-xl font-semibold">{label}</h2>
      <Textarea value={value} onChange={(e) => setValue(e.target.value)} disabled={locked} rows={10} />
      <div className="mt-2 flex items-center justify-between">
        <span className={`text-xs ${tooLong ? "text-destructive" : "text-muted-foreground"}`}>{value.length}/5000</span>
        {!locked && (
          <Button size="sm" disabled={busy || tooLong || value === initial} onClick={async () => {
            setBusy(true);
            try { await save(value); toast.success(`${label} saved`); } catch (e) { toast.error(friendlyError(e)); } finally { setBusy(false); }
          }}>{busy ? "Saving…" : saveLabel}</Button>
        )}
      </div>
    </section>
  );
}
