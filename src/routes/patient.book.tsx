import { useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { toast } from "sonner";
import { CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getAvailableSlots, listDoctors, type Doctor } from "@/shared/repositories";
import { rpc } from "@/shared/rpc";
import { useAsync } from "@/shared/hooks";
import { AsyncView, EmptyState, ErrorState, ListSkeleton, PageHeader } from "@/shared/ui";
import { addDays, clinicToday, dayOfWeek, formatDate, formatTime } from "@/shared/clinic";
import { friendlyError } from "@/shared/errors";
import { BOOKING_WINDOW_DAYS } from "@/config/constants";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/patient/book")({
  validateSearch: (s: Record<string, unknown>) => ({
    doctorId: s["doctorId"] !== undefined && Number.isFinite(Number(s["doctorId"])) ? Number(s["doctorId"]) : undefined,
  }),
  head: () => ({ meta: [{"title": "Book appointment — SMAQMS"}, {"name": "description", "content": "Choose your doctor, appointment date and available consultation time."}, {"property": "og:title", "content": "Book appointment — SMAQMS"}, {"property": "og:description", "content": "Choose your doctor, appointment date and available consultation time."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  component: BookingWizard,
});

const STEPS = ["Select doctor", "Select date", "Select time", "Confirmed"];

function BookingWizard() {
  const { doctorId } = Route.useSearch();
  const doctors = useAsync(listDoctors, []);
  const [picked, setPicked] = useState<number | undefined>(doctorId);
  const [date, setDate] = useState<string | null>(null);
  const [time, setTime] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);

  const doctor = doctors.data?.find((d) => d.doctorId === picked);
  const step = done ? 3 : !doctor ? 0 : !date ? 1 : 2;

  const confirm = async () => {
    if (!doctor || !date || !time) return;
    setBusy(true);
    try {
      await rpc.bookAppointment(doctor.doctorId, date, time);
      setDone(true);
      toast.success("Appointment confirmed");
    } catch (e) {
      toast.error(friendlyError(e));
      setTime(null);
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <PageHeader title="Book an appointment" />
      <ol className="mb-8 grid grid-cols-4 gap-2">
        {STEPS.map((s, i) => (
          <li key={s} className="flex flex-col gap-1.5">
            <span className={cn("h-1.5 rounded-full", i <= step ? "bg-primary" : "bg-muted")} />
            <span className={cn("text-xs font-medium", i === step ? "text-foreground" : "text-muted-foreground")}>{s}</span>
          </li>
        ))}
      </ol>

      <AsyncView state={doctors} empty={null}>
        {(list) => (
          <>
            {step === 0 && <SelectDoctor doctors={list} onPick={setPicked} />}
            {step === 1 && doctor && <SelectDate doctor={doctor} onPick={setDate} onBack={() => setPicked(undefined)} />}
            {step === 2 && doctor && date && (
              <SelectTime
                doctor={doctor} date={date} time={time} setTime={setTime} busy={busy}
                onBack={() => { setDate(null); setTime(null); }} onConfirm={confirm}
              />
            )}
            {step === 3 && doctor && date && time && (
              <div className="mx-auto max-w-md rounded-3xl border bg-card p-8 text-center shadow-soft">
                <CheckCircle2 className="mx-auto mb-3 size-12 text-success" />
                <h2 className="text-2xl font-semibold">Appointment confirmed</h2>
                <dl className="mt-5 space-y-2 text-sm">
                  <Row k="Doctor" v={doctor.name} />
                  <Row k="Specialization" v={doctor.specialization} />
                  <Row k="Date" v={formatDate(date)} />
                  <Row k="Time" v={formatTime(time)} />
                </dl>
                <div className="mt-6 flex gap-2">
                  <Button variant="outline" className="flex-1" onClick={() => { setDone(false); setDate(null); setTime(null); setPicked(undefined); }}>Book another</Button>
                  <Button className="flex-1" asChild><Link to="/patient/appointments">My appointments</Link></Button>
                </div>
              </div>
            )}
          </>
        )}
      </AsyncView>
    </>
  );
}

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex justify-between rounded-lg bg-muted/60 px-3 py-2">
      <dt className="text-muted-foreground">{k}</dt>
      <dd className="font-semibold text-foreground">{v}</dd>
    </div>
  );
}

function SelectDoctor({ doctors, onPick }: { doctors: Doctor[]; onPick: (id: number) => void }) {
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {doctors.map((d) => (
        <button key={d.doctorId} onClick={() => onPick(d.doctorId)} className="rounded-2xl border bg-card p-5 text-left transition hover:border-primary hover:shadow-soft">
          <p className="font-semibold text-foreground">{d.name}</p>
          <p className="text-sm text-muted-foreground">{d.specialization}</p>
        </button>
      ))}
    </div>
  );
}

function SelectDate({ doctor, onPick, onBack }: { doctor: Doctor; onPick: (d: string) => void; onBack: () => void }) {
  const today = clinicToday();
  const openDays = new Set(doctor.availability.map((a) => a.dayOfWeek));
  const dates = Array.from({ length: BOOKING_WINDOW_DAYS + 1 }, (_, i) => addDays(today, i));
  return (
    <div>
      <p className="mb-4 text-sm text-muted-foreground">With <span className="font-semibold text-foreground">{doctor.name}</span></p>
      <div className="grid grid-cols-3 gap-2 sm:grid-cols-5 lg:grid-cols-7">
        {dates.map((d) => {
          const open = openDays.has(dayOfWeek(d));
          return (
            <button
              key={d} disabled={!open} onClick={() => onPick(d)}
              className="rounded-xl border bg-card px-2 py-3 text-center text-sm transition hover:border-primary disabled:cursor-not-allowed disabled:opacity-40"
            >
              {formatDate(d).split(",").slice(0, 2).join(",")}
            </button>
          );
        })}
      </div>
      <Button variant="ghost" className="mt-4" onClick={onBack}>← Change doctor</Button>
    </div>
  );
}

function SelectTime(p: {
  doctor: Doctor; date: string; time: string | null; setTime: (t: string) => void;
  busy: boolean; onBack: () => void; onConfirm: () => void;
}) {
  const slots = useAsync(() => getAvailableSlots(p.doctor.doctorId, p.date), [p.doctor.doctorId, p.date]);
  return (
    <div>
      <p className="mb-4 text-sm text-muted-foreground">
        {p.doctor.name} · <span className="font-semibold text-foreground">{formatDate(p.date)}</span>
      </p>
      {slots.loading && !slots.data ? <ListSkeleton rows={2} /> : slots.error ? <ErrorState message={slots.error} onRetry={() => slots.reload()} /> :
        slots.data && slots.data.filter((s) => s.available).length === 0 ? <EmptyState title="No open slots this day" hint="Pick another date." /> : (
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
          {(slots.data ?? []).map((s) => (
            <button
              key={s.time} disabled={!s.available} onClick={() => p.setTime(s.time)}
              className={cn(
                "rounded-xl border px-2 py-2.5 text-sm font-medium transition disabled:cursor-not-allowed disabled:opacity-35",
                p.time === s.time ? "border-primary bg-primary text-primary-foreground" : "bg-card hover:border-primary",
              )}
            >
              {formatTime(s.time)}
            </button>
          ))}
        </div>
      )}
      <div className="mt-6 flex gap-2">
        <Button variant="ghost" onClick={p.onBack}>← Change date</Button>
        <Button className="ml-auto" disabled={!p.time || p.busy} onClick={p.onConfirm}>
          {p.busy ? "Booking…" : "Confirm appointment"}
        </Button>
      </div>
    </div>
  );
}
