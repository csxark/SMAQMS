import { createFileRoute, Outlet } from "@tanstack/react-router";
import { CalendarDays, ListOrdered, Search } from "lucide-react";
import { requireRole } from "@/auth/auth";
import { AppShell } from "@/shared/AppShell";

export const Route = createFileRoute("/patient")({
  head: () => ({ meta: [{"title": "Patient workspace \u2014 SMAQMS"}, {"name": "description", "content": "Your clinic appointments, doctors and live queue."}, {"property": "og:title", "content": "Patient workspace \u2014 SMAQMS"}, {"property": "og:description", "content": "Your clinic appointments, doctors and live queue."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  ssr: false,
  beforeLoad: ({ location }) => requireRole("patient", location.href),
  component: () => (
    <AppShell
      nav={[
        { to: "/patient/doctors", label: "Doctors", icon: Search },
        { to: "/patient/appointments", label: "Appointments", icon: CalendarDays },
        { to: "/patient/queue", label: "My queue", icon: ListOrdered },
      ]}
    >
      <Outlet />
    </AppShell>
  ),
});
