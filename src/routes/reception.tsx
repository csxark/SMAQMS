import { useRef, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import type { z } from "zod";
import { toast } from "sonner";
import { ClipboardCheck } from "lucide-react";
import { requireRole } from "@/auth/auth";
import { AppShell } from "@/shared/AppShell";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import {
  listConsultations, listDoctors, todaysAppointments, todaysQueue, type QueueEntry, type QueueStatus,
} from "@/shared/repositories";
import { rpc } from "@/shared/rpc";
import { useAsync, useRealtime } from "@/shared/hooks";
import { AsyncView, EmptyState, FieldError, PageHeader, StatusBadge } from "@/shared/ui";
import { ConfirmButton } from "@/shared/Confirm";
import { clinicToday, formatDate, formatTime } from "@/shared/clinic";
import { friendlyError } from "@/shared/errors";
import { walkInSchema } from "@/shared/schemas";

export const Route = createFileRoute("/reception")({
  ssr: false,
  beforeLoad: ({ location }) => requireRole("receptionist", location.href),
  head: () => ({ meta: [{"title": "Reception console — SMAQMS"}, {"name": "description", "content": "Manage clinic check-ins, walk-in visits, live queues and consultation verification."}, {"property": "og:title", "content": "Reception console — SMAQMS"}, {"property": "og:description", "content": "Manage clinic check-ins, walk-in visits, live queues and consultation verification."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  component: Console,
});

const tryRun = async (fn: () => Promise<unknown>, ok: string, after?: () => void) => {
  try { await fn(); toast.success(ok); after?.(); } catch (e) { toast.error(friendlyError(e)); }
};

function Console() {
  const queue = useAsync(todaysQueue, []);
  const appts = useAsync(() => todaysAppointments("confirmed"), []);
  const cons = useAsync(listConsultations, []);
  const doctors = useAsync(listDoctors, []);
  const seen = useRef<Set<number> | null>(null);
  const [verifyEntry, setVerifyEntry] = useState<QueueEntry | null>(null);

  const reloadAll = () => { void queue.reload(true); void appts.reload(true); void cons.reload(true); };
  useRealtime(["queue_entries", "appointments", "consultations"], (c) => {
    if (c?.table === "queue_entries" && c.eventType === "INSERT" && c.new["status"] === "checkin_requested") toast.info("New check-in request");
    if (c?.table === "consultations" && c.eventType === "UPDATE" && c.new["status"] === "completed" && c.old["status"] !== "completed") toast.info("Consultation status updated");
    reloadAll();
  });
  if (queue.data && seen.current === null) seen.current = new Set(queue.data.map((q) => q.queueId));

  const requests = (queue.data ?? []).filter((q) => q.status === "checkin_requested");
  const pendingCons = (cons.data ?? []).filter((c) => c.status === "completed" && !c.verifiedAt);
  const inConsult = (queue.data ?? []).filter((q) => q.status === "in_consultation");

  return (
    <AppShell nav={[]}>
      <PageHeader title="Reception" subtitle={formatDate(clinicToday())} action={<span className="flex items-center gap-2 text-xs font-medium text-muted-foreground"><span className="size-2 rounded-full bg-success" /> Live clinic</span>} />
      <div className="mb-8 grid grid-cols-3 divide-x border-y bg-card py-5">
        {[["Check-in requests", requests.length], ["In consultation", inConsult.length], ["Awaiting verification", pendingCons.length]].map(([label, value]) => (
          <div key={label} className="px-3 sm:px-6"><p className="text-[11px] font-medium text-muted-foreground sm:text-xs">{label}</p><p className="mt-2 text-3xl font-semibold text-primary">{queue.data === null ? "—" : value}</p></div>
        ))}
      </div>
      <Tabs defaultValue="requests">
        <TabsList className="mb-6 flex h-auto flex-wrap justify-start gap-0">
          <TabsTrigger value="requests">Check-in requests {requests.length > 0 && <span className="ml-1.5 rounded-full bg-warning px-1.5 text-xs text-warning-foreground">{requests.length}</span>}</TabsTrigger>
          <TabsTrigger value="appointments">Today's appointments</TabsTrigger>
          <TabsTrigger value="walkin">Walk-in</TabsTrigger>
          <TabsTrigger value="queue">Queue</TabsTrigger>
          <TabsTrigger value="consultations">Consultations {pendingCons.length > 0 && <span className="ml-1.5 rounded-full bg-primary px-1.5 text-xs text-primary-foreground">{pendingCons.length}</span>}</TabsTrigger>
        </TabsList>

        <TabsContent value="requests">
          <AsyncView state={queue} isEmpty={() => requests.length === 0} empty={<EmptyState title="No pending check-ins" hint="New requests appear here live." />}>
            {() => (
              <ul className="space-y-3">
                {requests.map((q) => (
                  <li key={q.queueId} className="flex flex-wrap items-center gap-3 rounded-2xl border bg-card p-4">
                    <div className="flex-1">
                      <p className="font-semibold text-foreground">{q.patientName}</p>
                      <p className="text-sm text-muted-foreground">{q.doctorName}{q.appointmentTime ? ` · ${formatTime(q.appointmentTime)}` : ""} · {q.patientPhone}</p>
                    </div>
                    <ConfirmButton size="sm" variant="outline" title="Reject this check-in?" description="The appointment goes back to confirmed." confirmLabel="Reject"
                      onConfirm={() => tryRun(() => rpc.updateQueueStatus(q.queueId, "cancelled"), "Check-in rejected", reloadAll)}>Reject</ConfirmButton>
                    <Button size="sm" onClick={() => setVerifyEntry(q)}>Check-in patient</Button>
                  </li>
                ))}
              </ul>
            )}
          </AsyncView>
        </TabsContent>

        <TabsContent value="appointments">
          <AsyncView state={appts} isEmpty={(d) => d.length === 0} empty={<EmptyState title="No confirmed appointments left today" />}>
            {(rows) => (
              <ul className="space-y-3">
                {rows.map((a) => (
                  <li key={a.appointmentId} className="flex flex-wrap items-center gap-3 rounded-2xl border bg-card p-4">
                    <span className="w-20 font-semibold text-foreground">{formatTime(a.time)}</span>
                    <div className="flex-1">
                      <p className="font-semibold text-foreground">{a.patientName}</p>
                      <p className="text-sm text-muted-foreground">{a.doctorName}</p>
                    </div>
                    <StatusBadge status={a.status} />
                    <Button size="sm" onClick={async () => {
                      try {
                        const qid = await rpc.receptionistCheckIn(a.appointmentId);
                        const fresh = await todaysQueue();
                        reloadAll();
                        setVerifyEntry(fresh.find((x) => x.queueId === qid) ?? null);
                      } catch (e) { toast.error(friendlyError(e)); }
                    }}>Check-in patient</Button>
                  </li>
                ))}
              </ul>
            )}
          </AsyncView>
        </TabsContent>

        <TabsContent value="walkin">
          <WalkIn doctors={doctors.data ?? []} onDone={reloadAll} />
        </TabsContent>

        <TabsContent value="queue">
          <QueueTab state={queue} doctors={doctors.data ?? []} reload={reloadAll} />
        </TabsContent>

        <TabsContent value="consultations">
          <AsyncView state={cons} isEmpty={() => pendingCons.length === 0 && inConsult.length === 0} empty={<EmptyState title="Nothing to verify" hint="Completed consultations appear here." />}>
            {() => (
              <div className="space-y-6">
                {pendingCons.length > 0 && (
                  <ul className="space-y-3">
                    {pendingCons.map((c) => (
                      <li key={c.consultationId} className="flex flex-wrap items-center gap-3 rounded-2xl border bg-card p-4">
                        <div className="flex-1">
                          <p className="font-semibold text-foreground">{c.patientName}</p>
                          <p className="text-sm text-muted-foreground">{c.doctorName} · {formatDate(c.date)}</p>
                        </div>
                        <StatusBadge status={c.status} />
                        <Button size="sm" onClick={() => tryRun(() => rpc.verifyConsultation(c.consultationId), "Status verified", reloadAll)}>Verify consultation status</Button>
                      </li>
                    ))}
                  </ul>
                )}
                {inConsult.length > 0 && (
                  <div>
                    <h3 className="mb-3 text-lg font-semibold">In consultation</h3>
                    <ul className="space-y-3">
                      {inConsult.map((q) => {
                        const ready = q.consultation?.status === "completed" && !!q.consultation.verifiedAt;
                        return (
                          <li key={q.queueId} className="flex flex-wrap items-center gap-3 rounded-2xl border bg-card p-4">
                            <div className="flex-1">
                              <p className="font-semibold text-foreground">{q.patientName}</p>
                              <p className="text-sm text-muted-foreground">{q.doctorName}</p>
                            </div>
                            <StatusBadge status={q.status} />
                            <Button size="sm" variant={ready ? "default" : "outline"} disabled={!ready}
                              onClick={() => tryRun(() => rpc.updateQueueStatus(q.queueId, "completed"), "Queue updated: completed", reloadAll)}>
                              {ready ? "Update queue status: Completed" : "Awaiting verification"}
                            </Button>
                          </li>
                        );
                      })}
                    </ul>
                  </div>
                )}
              </div>
            )}
          </AsyncView>
        </TabsContent>
      </Tabs>

      <VerifyDialog entry={verifyEntry} onClose={() => setVerifyEntry(null)} onDone={reloadAll} />
    </AppShell>
  );
}

function VerifyDialog({ entry, onClose, onDone }: { entry: QueueEntry | null; onClose: () => void; onDone: () => void }) {
  const [checked, setChecked] = useState(false);
  const [busy, setBusy] = useState(false);
  return (
    <Dialog open={!!entry} onOpenChange={(o) => { if (!o) { setChecked(false); onClose(); } }}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Verify patient</DialogTitle>
          <DialogDescription>Confirm identity before adding to the queue.</DialogDescription>
        </DialogHeader>
        {entry && (
          <dl className="space-y-2 text-sm">
            {[["Patient", entry.patientName], ["Phone", entry.patientPhone], ["Doctor", entry.doctorName], ["Appointment", entry.appointmentTime ? formatTime(entry.appointmentTime) : "Walk-in"]].map(([k, v]) => (
              <div key={k} className="flex justify-between rounded-lg bg-muted/60 px-3 py-2"><dt className="text-muted-foreground">{k}</dt><dd className="font-semibold text-foreground">{v}</dd></div>
            ))}
          </dl>
        )}
        <label className="flex items-center gap-2 text-sm">
          <Checkbox checked={checked} onCheckedChange={(v) => setChecked(v === true)} />
          I have verified the patient's identity
        </label>
        <DialogFooter>
          <Button disabled={!checked || busy || !entry} onClick={async () => {
            if (!entry) return;
            setBusy(true);
            try {
              const pos = await rpc.verifyAndAddToQueue(entry.queueId);
              toast.success(`Added to queue at position #${pos}`);
              setChecked(false); onDone(); onClose();
            } catch (e) { toast.error(friendlyError(e)); } finally { setBusy(false); }
          }}><ClipboardCheck /> {busy ? "Adding…" : "Verify & add to queue"}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

type WalkInIn = z.input<typeof walkInSchema>;
type WalkInOut = z.output<typeof walkInSchema>;

function WalkIn({ doctors, onDone }: { doctors: { doctorId: number; name: string; specialization: string }[]; onDone: () => void }) {
  const [result, setResult] = useState<number | null>(null);
  const { register, handleSubmit, setValue, watch, reset, formState: { errors, isSubmitting } } = useForm<WalkInIn, unknown, WalkInOut>({
    resolver: zodResolver(walkInSchema), defaultValues: { name: "", phone: "", email: "", doctorId: "" },
  });
  const onSubmit = async (v: WalkInOut) => {
    try {
      const rows = await rpc.registerWalkIn(v.name, v.phone, v.email, Number(v.doctorId));
      setResult(rows?.[0]?.queue_position ?? null);
      toast.success("Walk-in added to queue");
      reset(); onDone();
    } catch (e) { toast.error(friendlyError(e)); }
  };
  return (
    <div className="grid gap-6 md:grid-cols-2">
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 rounded-2xl border bg-card p-5" noValidate>
        <h3 className="text-xl font-semibold">Register walk-in patient</h3>
        <div><Label htmlFor="wn">Name</Label><Input id="wn" {...register("name")} /><FieldError msg={errors.name?.message} /></div>
        <div><Label htmlFor="wp">Phone</Label><Input id="wp" type="tel" {...register("phone")} /><FieldError msg={errors.phone?.message} /></div>
        <div><Label htmlFor="we">Email (optional)</Label><Input id="we" type="email" {...register("email")} /><FieldError msg={errors.email?.message} /></div>
        <div>
          <Label>Doctor</Label>
          <Select value={watch("doctorId")} onValueChange={(v) => setValue("doctorId", v, { shouldValidate: true })}>
            <SelectTrigger><SelectValue placeholder="Choose doctor" /></SelectTrigger>
            <SelectContent>{doctors.map((d) => <SelectItem key={d.doctorId} value={String(d.doctorId)}>{d.name} — {d.specialization}</SelectItem>)}</SelectContent>
          </Select>
          <FieldError msg={errors.doctorId?.message} />
        </div>
        <Button type="submit" disabled={isSubmitting} className="w-full">{isSubmitting ? "Adding…" : "Add to queue"}</Button>
      </form>
      {result !== null && (
        <div className="flex flex-col items-center justify-center rounded-2xl bg-hero p-8 text-center">
          <p className="text-sm font-semibold text-accent-foreground">Queue position</p>
          <p className="font-display text-7xl font-semibold text-foreground">#{result}</p>
        </div>
      )}
    </div>
  );
}

function QueueTab({ state, doctors, reload }: {
  state: { data: QueueEntry[] | null; error: string | null; loading: boolean; reload: () => void };
  doctors: { doctorId: number; name: string }[]; reload: () => void;
}) {
  const [doc, setDoc] = useState("all");
  const [status, setStatus] = useState<"all" | QueueStatus>("all");
  const rows = (state.data ?? []).filter((q) => (doc === "all" || String(q.doctorId) === doc) && (status === "all" || q.status === status));
  return (
    <>
      <div className="mb-4 flex flex-wrap gap-3">
        <Select value={doc} onValueChange={setDoc}>
          <SelectTrigger className="w-56"><SelectValue /></SelectTrigger>
          <SelectContent><SelectItem value="all">All doctors</SelectItem>{doctors.map((d) => <SelectItem key={d.doctorId} value={String(d.doctorId)}>{d.name}</SelectItem>)}</SelectContent>
        </Select>
        <Select value={status} onValueChange={(v) => setStatus(v as typeof status)}>
          <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
          <SelectContent>
            {["all", "checkin_requested", "waiting", "in_consultation", "completed", "cancelled"].map((s) => <SelectItem key={s} value={s} className="capitalize">{s === "all" ? "All statuses" : s.replace("_", " ")}</SelectItem>)}
          </SelectContent>
        </Select>
      </div>
      <AsyncView state={state} isEmpty={() => rows.length === 0} empty={<EmptyState title="No queue entries" />}>
        {() => (
          <div className="rounded-2xl border bg-card">
            <Table>
              <TableHeader><TableRow><TableHead>#</TableHead><TableHead>Patient</TableHead><TableHead>Doctor</TableHead><TableHead>Status</TableHead><TableHead className="text-right">Action</TableHead></TableRow></TableHeader>
              <TableBody>
                {rows.map((q) => {
                  const canComplete = q.status === "in_consultation" && q.consultation?.status === "completed" && !!q.consultation.verifiedAt;
                  return (
                    <TableRow key={q.queueId}>
                      <TableCell className="font-semibold">{q.position ?? "—"}</TableCell>
                      <TableCell>{q.patientName}{!q.appointmentId && <span className="ml-1 text-xs text-muted-foreground">(walk-in)</span>}</TableCell>
                      <TableCell>{q.doctorName}</TableCell>
                      <TableCell><StatusBadge status={q.status} /></TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-2">
                          {q.status === "waiting" && (
                            <Button size="sm" onClick={() => tryRun(() => rpc.startConsultation(q.queueId), "Consultation started", reload)}>Start consultation</Button>
                          )}
                          {(q.status === "checkin_requested" || q.status === "waiting") && (
                            <ConfirmButton size="sm" variant="outline" title="Cancel this queue entry?" description={q.patientName} confirmLabel="Cancel entry"
                              onConfirm={() => tryRun(() => rpc.updateQueueStatus(q.queueId, "cancelled"), "Queue entry cancelled", reload)}>Cancel</ConfirmButton>
                          )}
                          {canComplete && <Button size="sm" onClick={() => tryRun(() => rpc.updateQueueStatus(q.queueId, "completed"), "Marked completed", reload)}>Mark completed</Button>}
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        )}
      </AsyncView>
    </>
  );
}
