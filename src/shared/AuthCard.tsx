import type { ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { ArrowLeft, Stethoscope } from "lucide-react";
import consultationImg from "@/assets/clinic-consultation.jpg";

export function AuthCard({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
}) {
  return (
    <div className="grid min-h-screen bg-card lg:grid-cols-2">
      <div className="relative hidden overflow-hidden bg-hero-surface lg:block">
        <img
          src={consultationImg}
          alt="Doctor and patient in consultation"
          width={1536}
          height={1024}
          className="absolute inset-0 h-full w-full object-cover object-right"
        />
        <div className="absolute inset-x-0 top-0 bg-hero-surface/90 px-12 py-12">
          <Link to="/" className="flex items-center gap-3 text-hero-ink">
            <Stethoscope className="size-7" />
            <span className="text-2xl font-extrabold">SMAQMS.</span>
          </Link>
          <h2 className="mt-12 font-display text-5xl font-medium leading-tight text-hero-ink">
            Good care.
            <br />A simpler clinic day.
          </h2>
        </div>
      </div>
      <div className="flex flex-col px-6 py-8 sm:px-12">
        <Link
          to="/"
          className="flex w-fit items-center gap-2 text-xs font-semibold text-muted-foreground hover:text-primary"
        >
          <ArrowLeft className="size-4" /> Back to clinic
        </Link>
        <div className="mx-auto my-auto w-full max-w-sm py-12">
          <span className="mb-8 flex items-center gap-2 text-lg font-extrabold text-foreground lg:hidden">
            <Stethoscope className="size-5 text-primary" /> SMAQMS.
          </span>
          <p className="mb-3 text-xs font-bold uppercase tracking-widest text-primary">
            Your clinic account
          </p>
          <h1 className="text-3xl font-bold text-foreground">{title}</h1>
          <p className="mb-8 mt-3 text-sm leading-6 text-muted-foreground">{subtitle}</p>
          {children}
        </div>
        <p className="text-center text-[11px] text-muted-foreground">
          Smart Medical Appointment & Queue Management
        </p>
      </div>
    </div>
  );
}
