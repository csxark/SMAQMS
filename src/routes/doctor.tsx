import { createFileRoute, Outlet } from "@tanstack/react-router";
import { CalendarDays, ListOrdered } from "lucide-react";
import { requireRole } from "@/auth/auth";
import { AppShell } from "@/shared/AppShell";

export const Route = createFileRoute("/doctor")({
  head: () => ({ meta: [{"title": "Doctor workspace \u2014 SMAQMS"}, {"name": "description", "content": "Your clinic appointment list and patient consultation queue."}, {"property": "og:title", "content": "Doctor workspace \u2014 SMAQMS"}, {"property": "og:description", "content": "Your clinic appointment list and patient consultation queue."}, {"property": "og:type", "content": "website"}, {"name": "twitter:card", "content": "summary"}] }),
  ssr: false,
  beforeLoad: ({ location }) => requireRole("doctor", location.href),
  component: () => (
    <AppShell
      nav={[
        { to: "/doctor/appointments", label: "Today", icon: CalendarDays },
        { to: "/doctor/queue", label: "Patient queue", icon: ListOrdered },
      ]}
    >
      <Outlet />
    </AppShell>
  ),
});
