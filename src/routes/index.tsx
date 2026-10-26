import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowDown, ArrowRight, ArrowUpRight, CalendarDays, Circle, Stethoscope } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useAuth, ROLE_HOME } from "@/auth/auth";
import { useAsync, useRealtime } from "@/shared/hooks";
import { publicQueueBoard } from "@/shared/repositories";
import { AsyncView } from "@/shared/ui";
import consultationImg from "@/assets/clinic-consultation.jpg";

export const Route = createFileRoute("/")({
  head: () => ({ meta: [
    { title: "SMAQMS — Appointments & Live Clinic Queue" },
    { name: "description", content: "Your next appointment, and the clinic queue right now. Book a doctor and follow live consultation numbers with SMAQMS." },
    { property: "og:title", content: "SMAQMS — Appointments & Live Clinic Queue" },
    { property: "og:description", content: "Book your next appointment and follow the clinic queue live." },
    { property: "og:type", content: "website" },
    { name: "twitter:card", content: "summary_large_image" },
  ] }),
  component: Index,
});

function LiveQueueBoard() {
  const state = useAsync(publicQueueBoard, []);
  useRealtime(["queue_entries"], () => void state.reload(true));
  return (
    <section id="live-queue" className="scroll-mt-6 border-b bg-card">
      <div className="mx-auto max-w-7xl px-5 py-10 md:px-10 md:py-12">
        <div className="mb-7 flex flex-wrap items-end justify-between gap-4">
          <div>
            <p className="mb-2 flex items-center gap-2 text-xs font-bold uppercase tracking-widest text-primary"><span className="size-1.5 rounded-full bg-success" /> At the clinic</p>
            <h2 className="text-3xl font-bold">The queue, right now.</h2>
          </div>
          <span className="flex items-center gap-2 text-xs font-medium text-muted-foreground"><span className="size-2 rounded-full bg-success motion-safe:animate-pulse" /> Live queue</span>
        </div>
        <AsyncView state={state} empty={null}>
          {(rows) => rows.length === 0 ? <p className="border-y py-8 text-sm text-muted-foreground">No doctors in the queue today.</p> : (
            <div className="grid border-t md:grid-cols-3">
              {rows.map((r, i) => (
                <div key={r.doctorId} className="border-b py-6 md:border-b-0 md:px-6 md:first:pl-0 md:last:pr-0 md:[&:not(:last-child)]:border-r">
                  <div className="mb-6 flex items-start gap-3">
                    <span className="grid size-10 shrink-0 place-items-center rounded-full bg-muted text-xs font-bold text-primary">{r.doctorName.replace("Dr. ", "").split(" ").map(p => p[0]).join("")}</span>
                    <div><h3 className="text-sm font-bold">{r.doctorName}</h3><p className="mt-1 text-xs text-muted-foreground">{r.specialization}</p></div>
                    <span className="ml-auto text-xs text-muted-foreground">0{i + 1}</span>
                  </div>
                  <div className="flex items-end justify-between gap-4">
                    <div><p className="mb-1 text-xs font-medium text-muted-foreground">Now serving</p><p className="queue-number text-5xl font-semibold leading-none text-primary">{r.nowServing === null ? "—" : String(r.nowServing).padStart(2, "0")}</p></div>
                    <div className="pb-1 text-right"><p className="text-sm font-semibold">{r.waitingCount} waiting</p><p className="mt-1 text-xs text-muted-foreground">{r.nowServing !== null ? "In consultation" : "No active consultation"}</p></div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </AsyncView>
      </div>
    </section>
  );
}

function Index() {
  const { session, role } = useAuth();
  const home = role ? ROLE_HOME[role] : "/login";
  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card">
        <div className="mx-auto flex h-20 max-w-7xl items-center gap-5 px-5 md:px-10">
          <Link to="/" className="flex items-center gap-2.5 text-foreground"><Stethoscope className="size-7 text-primary" /><span className="text-xl font-extrabold">SMAQMS<span className="text-primary">.</span></span></Link>
          <span className="hidden border-l pl-5 text-xs leading-relaxed text-muted-foreground lg:block">Medical appointments.<br />A better clinic day.</span>
          <nav className="ml-auto flex items-center gap-2 md:gap-6">
            <a href="#live-queue" className="hidden items-center gap-2 text-sm font-semibold text-muted-foreground hover:text-primary sm:flex"><span className="size-1.5 rounded-full bg-success" /> Live queue</a>
            {session ? <Button asChild><Link to={home}>Dashboard <ArrowUpRight /></Link></Button> : <><Button variant="ghost" asChild><Link to="/login" search={{ redirect: undefined }}>Log in</Link></Button><Button asChild><Link to="/register">Book a visit <ArrowUpRight /></Link></Button></>}
          </nav>
        </div>
      </header>

      <section className="clinic-hero relative isolate overflow-hidden bg-hero-surface">
        <img src={consultationImg} alt="A doctor listening to a patient in a bright, modern clinic" width={1536} height={1024} fetchPriority="high" className="clinic-hero-image absolute inset-0 -z-10 h-full w-full object-cover" />
        <div className="mx-auto flex min-h-[510px] max-w-7xl flex-col justify-center px-5 py-12 md:px-10">
          <div className="max-w-[530px]">
            <p className="mb-6 text-xs font-bold uppercase tracking-widest text-hero-muted">Your care. Your time.</p>
            <h1 className="clinic-hero-title font-display font-medium text-hero-ink">SMAQMS<span className="text-primary">.</span></h1>
            <h2 className="mt-5 max-w-[400px] text-3xl font-semibold leading-tight text-hero-ink md:text-4xl">A little less waiting.<br />A lot more care.</h2>
            <p className="mt-5 max-w-[350px] text-sm leading-7 text-hero-muted">Your next appointment, a simpler check-in, and your place in the queue. All in one place.</p>
            <div className="mt-7 flex flex-wrap items-center gap-5">
              <Button size="lg" asChild><Link to={session ? home : "/register"}>{session ? "Open dashboard" : "Book an appointment"}<ArrowUpRight /></Link></Button>
              <a href="#live-queue" className="flex items-center gap-2 text-sm font-semibold text-hero-ink">View live queue <ArrowDown className="size-4" /></a>
            </div>
          </div>
        </div>
        <div className="absolute bottom-5 right-6 hidden items-center gap-2 text-xs font-semibold text-hero-ink md:flex"><Circle className="size-2 fill-current" /> Care starts with a conversation.</div>
      </section>

      <LiveQueueBoard />

      <section className="mx-auto max-w-7xl px-5 py-14 md:px-10 md:py-20">
        <div className="grid gap-10 md:grid-cols-[1fr_1.8fr] md:gap-16">
          <div><p className="mb-3 text-xs font-bold uppercase tracking-widest text-primary">Your next visit</p><h2 className="font-display text-4xl font-medium leading-tight">Less to manage.<br />More peace of mind.</h2><Button variant="link" className="mt-5 p-0" asChild><Link to={session ? home : "/register"}>Make an appointment <ArrowRight /></Link></Button></div>
          <div className="divide-y border-y">
            {[
              {n:"01", title:"The right doctor, at the right time.", text:"Choose your doctor and an appointment that fits your day."},
              {n:"02", title:"Arrive. Check in. You're on the list.", text:"Request check-in when you arrive. Reception takes it from there."},
              {n:"03", title:"Know where you stand.", text:"Follow your queue position as your doctor sees each patient."},
            ].map(item => <div key={item.n} className="flex gap-6 py-6"><span className="pt-1 text-xs font-semibold text-primary">{item.n}</span><div><h3 className="text-lg font-semibold">{item.title}</h3><p className="mt-2 text-sm leading-6 text-muted-foreground">{item.text}</p></div></div>)}
          </div>
        </div>
      </section>

      <section className="border-y bg-accent">
        <div className="mx-auto flex max-w-7xl flex-col justify-between gap-6 px-5 py-10 sm:flex-row sm:items-center md:px-10">
          <div className="flex items-center gap-5"><CalendarDays className="hidden size-9 text-primary sm:block" /><div><h2 className="text-2xl font-bold">Make time for your health.</h2><p className="mt-2 text-sm text-muted-foreground">Your next visit starts here.</p></div></div>
          <Button size="lg" asChild><Link to={session ? home : "/register"}>{session ? "Open dashboard" : "Book your visit"}<ArrowUpRight /></Link></Button>
        </div>
      </section>
      <footer className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-5 py-7 text-xs text-muted-foreground md:px-10">
        <span className="flex items-center gap-2 font-bold text-foreground"><Stethoscope className="size-4" /> SMAQMS.</span><span>Smart Medical Appointment & Queue Management</span><Link to="/login" search={{redirect:undefined}} className="flex items-center gap-1 font-semibold hover:text-primary">Staff access <ArrowUpRight className="size-3" /></Link>
      </footer>
    </div>
  );
}
