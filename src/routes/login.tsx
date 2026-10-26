import { useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import type { z } from "zod";
import { toast } from "sonner";
import { ChevronDown } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { loginSchema } from "@/shared/schemas";
import { FieldError } from "@/shared/ui";
import { friendlyError } from "@/shared/errors";
import { fetchRole, ROLE_HOME } from "@/auth/auth";
import { DEMO_ACCOUNTS, DEMO_PASSWORD, SHOW_DEMO_CREDENTIALS } from "@/config/constants";
import { AuthCard } from "@/shared/AuthCard";

export const Route = createFileRoute("/login")({
  validateSearch: (s: Record<string, unknown>) => ({
    redirect: typeof s["redirect"] === "string" && s["redirect"].startsWith("/") ? s["redirect"] : undefined,
  }),
  head: () => ({
    meta: [
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
      { title: "Log in — SMAQMS" },
      { name: "description", content: "Log in as a patient, doctor or receptionist." },
      { property: "og:title", content: "Log in — SMAQMS" },
      { property: "og:description", content: "Log in to the clinic appointment and queue system." },
    ],
  }),
  component: LoginPage,
});

type Form = z.input<typeof loginSchema>;

function LoginPage() {
  const { redirect } = Route.useSearch();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const { register, handleSubmit, setValue, formState: { errors, isSubmitting } } = useForm<Form>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = async (v: Form) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email: v.email.trim().toLowerCase(), password: v.password });
    if (error) return void toast.error(friendlyError(error));
    const role = await fetchRole(data.user.id);
    if (!role) return void toast.error("This account has no role assigned.");
    const target = redirect && redirect.startsWith(`/${role === "receptionist" ? "reception" : role}`) ? redirect : ROLE_HOME[role];
    window.location.assign(target);
    void navigate;
  };

  return (
    <AuthCard title="Welcome back" subtitle="One login for patients, doctors and reception.">
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
        <div>
          <Label htmlFor="email">Email</Label>
          <Input id="email" type="email" autoComplete="email" {...register("email")} />
          <FieldError msg={errors.email?.message} />
        </div>
        <div>
          <Label htmlFor="password">Password</Label>
          <Input id="password" type="password" autoComplete="current-password" {...register("password")} />
          <FieldError msg={errors.password?.message} />
        </div>
        <Button type="submit" className="w-full" disabled={isSubmitting}>
          {isSubmitting ? "Logging in…" : "Log in"}
        </Button>
      </form>
      <p className="mt-4 text-center text-sm text-muted-foreground">
        New patient? <Link to="/register" className="font-semibold text-primary">Create an account</Link>
      </p>
      {SHOW_DEMO_CREDENTIALS && (
        <div className="mt-6 rounded-xl border bg-muted/50">
          <Button variant="ghost" type="button" onClick={() => setOpen((o) => !o)} className="h-auto w-full justify-between px-4 py-3 text-sm font-semibold text-foreground">
            Demo accounts <ChevronDown className={`size-4 transition-transform ${open ? "rotate-180" : ""}`} />
          </Button>
          {open && (
            <div className="space-y-1 px-2 pb-3">
              <p className="px-2 pb-1 text-xs text-muted-foreground">Password for all: <code className="font-semibold text-foreground">{DEMO_PASSWORD}</code></p>
              {DEMO_ACCOUNTS.map((a) => (
                <Button
                  variant="ghost"
                  key={a.email}
                  type="button"
                  onClick={() => { setValue("email", a.email); setValue("password", DEMO_PASSWORD); }}
                  className="h-auto w-full justify-between rounded-md px-2 py-2 text-left text-sm hover:bg-card"
                >
                  <span className="text-foreground">{a.name}</span>
                  <span className="text-xs text-muted-foreground">{a.role}</span>
                </Button>
              ))}
            </div>
          )}
        </div>
      )}
    </AuthCard>
  );
}
