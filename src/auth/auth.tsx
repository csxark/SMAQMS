import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { redirect } from "@tanstack/react-router";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";
import type { AppRole } from "@/shared/repositories";

export const ROLE_HOME: Record<AppRole, string> = {
  patient: "/patient/doctors",
  doctor: "/doctor/appointments",
  receptionist: "/reception",
};

export async function fetchRole(userId: string): Promise<AppRole | null> {
  const { data } = await supabase.from("user_roles").select("role").eq("user_id", userId);
  const roles = (data ?? []).map((r) => r.role);
  if (roles.includes("doctor")) return "doctor";
  if (roles.includes("receptionist")) return "receptionist";
  if (roles.includes("patient")) return "patient";
  return null;
}

async function fetchName(role: AppRole, userId: string): Promise<string> {
  const table = role === "patient" ? "patients" : role === "doctor" ? "doctors" : "receptionists";
  const { data } = await supabase.from(table).select("name").eq("user_id", userId).maybeSingle();
  return data?.name ?? "";
}

/** Route guard: run in beforeLoad of client-only role layouts. */
export async function requireRole(role: AppRole, href: string) {
  const { data } = await supabase.auth.getUser();
  if (!data.user) throw redirect({ to: "/login", search: { redirect: href } });
  const actual = await fetchRole(data.user.id);
  if (!actual) throw redirect({ to: "/login", search: { redirect: href } });
  if (actual !== role) throw redirect({ to: ROLE_HOME[actual] });
}

type AuthState = { session: Session | null; role: AppRole | null; name: string; loading: boolean };
const AuthCtx = createContext<AuthState & { signOut: () => Promise<void> }>({
  session: null, role: null, name: "", loading: true, signOut: async () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ session: null, role: null, name: "", loading: true });

  useEffect(() => {
    const load = async (session: Session | null) => {
      if (!session) return setState({ session: null, role: null, name: "", loading: false });
      const role = await fetchRole(session.user.id);
      const name = role ? await fetchName(role, session.user.id) : "";
      setState({ session, role, name, loading: false });
    };
    const { data: sub } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_IN" || event === "SIGNED_OUT" || event === "USER_UPDATED") {
        setTimeout(() => void load(session), 0);
      }
    });
    void supabase.auth.getSession().then(({ data }) => load(data.session));
    return () => sub.subscription.unsubscribe();
  }, []);

  return (
    <AuthCtx.Provider value={{ ...state, signOut: async () => { await supabase.auth.signOut(); } }}>
      {children}
    </AuthCtx.Provider>
  );
}

export const useAuth = () => useContext(AuthCtx);
