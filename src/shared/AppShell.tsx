import type { ReactNode } from "react";
import { Link, useNavigate } from "@tanstack/react-router";
import { LogOut, Stethoscope, type LucideIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/auth/auth";
import { APP_SHORT } from "@/config/constants";
import { clinicToday, formatDate } from "@/shared/clinic";

export type NavItem = { to: string; label: string; icon: LucideIcon };

export function AppShell({ nav, children }: { nav: NavItem[]; children: ReactNode }) {
  const { name, role, signOut } = useAuth();
  const navigate = useNavigate();
  return (
    <div className="workspace min-h-screen bg-background pb-20 md:pb-0">
      <header className="sticky top-0 z-30 border-b bg-card">
        <div className="mx-auto flex h-[72px] max-w-7xl items-center gap-4 px-5 md:px-10">
          <Link to="/" className="flex items-center gap-2.5 text-foreground"><Stethoscope className="size-6 text-primary" /><span className="text-lg font-extrabold">{APP_SHORT}.</span></Link>
          <span className="hidden border-l pl-5 text-xs font-semibold capitalize text-muted-foreground lg:block">{role === "receptionist" ? "Reception workspace" : `${role} workspace`}</span>
          <div className="ml-auto flex items-center gap-3">
            <span className="hidden items-center gap-2 text-xs text-muted-foreground lg:flex"><span className="size-1.5 rounded-full bg-success" /> Live clinic</span>
            <div className="flex items-center gap-2.5 border-l pl-4"><span className="grid size-8 place-items-center rounded-full bg-accent text-xs font-bold text-accent-foreground">{name?.split(" ").map(p => p[0]).slice(0,2).join("") || "U"}</span><div className="hidden sm:block"><p className="text-xs font-bold text-foreground">{name}</p><p className="mt-0.5 text-[11px] capitalize text-muted-foreground">{role}</p></div></div>
            <Button variant="ghost" size="icon" aria-label="Log out" title="Log out" onClick={async () => { await signOut(); void navigate({to:"/login",search:{redirect:undefined}}); }}><LogOut /></Button>
          </div>
        </div>
      </header>
      {nav.length > 0 && <div className="hidden border-b bg-card md:block"><div className="mx-auto flex max-w-7xl items-center justify-between px-10"><nav className="flex gap-7">{nav.map(n => <Link key={n.to} to={n.to} className="flex items-center gap-2 border-b-2 border-transparent py-4 text-sm font-semibold text-muted-foreground hover:text-primary" activeProps={{className:"border-primary text-primary"}}><n.icon className="size-4" />{n.label}</Link>)}</nav><span className="text-xs text-muted-foreground">{formatDate(clinicToday())}</span></div></div>}
      <main className="mx-auto max-w-7xl px-5 py-8 md:px-10 md:py-10">{children}</main>
      {nav.length > 1 && <nav className="fixed inset-x-0 bottom-0 z-30 flex border-t bg-card md:hidden">{nav.map(n => <Link key={n.to} to={n.to} className="flex min-h-16 flex-1 flex-col items-center justify-center gap-1 text-xs font-semibold text-muted-foreground" activeProps={{className:"bg-accent/50 text-primary"}}><n.icon className="size-5" />{n.label}</Link>)}</nav>}
    </div>
  );
}
