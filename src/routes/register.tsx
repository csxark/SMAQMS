import { useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import type { z } from "zod";
import { toast } from "sonner";
import { MailCheck } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { registerSchema } from "@/shared/schemas";
import { FieldError } from "@/shared/ui";
import { friendlyError } from "@/shared/errors";
import { AuthCard } from "@/shared/AuthCard";

export const Route = createFileRoute("/register")({
  head: () => ({
    meta: [
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
      { title: "Register as a patient — SMAQMS" },
      { name: "description", content: "Create a patient account to book appointments and check in." },
      { property: "og:title", content: "Register as a patient — SMAQMS" },
      { property: "og:description", content: "Create a patient account to book clinic appointments." },
    ],
  }),
  component: RegisterPage,
});

type In = z.input<typeof registerSchema>;
type Out = z.output<typeof registerSchema>;

function RegisterPage() {
  const [sent, setSent] = useState(false);
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<In, unknown, Out>({
    resolver: zodResolver(registerSchema),
  });

  const onSubmit = async (v: Out) => {
    const { data, error } = await supabase.auth.signUp({
      email: v.email,
      password: v.password,
      options: { emailRedirectTo: window.location.origin, data: { name: v.name, phone: v.phone } },
    });
    if (error) return void toast.error(friendlyError(error));
    if (!data.session) return setSent(true);
    window.location.assign("/patient/doctors");
  };

  if (sent)
    return (
      <AuthCard title="Check your email" subtitle="Confirm your address, then log in.">
        <MailCheck className="mb-4 size-10 text-primary" />
        <p className="text-sm text-muted-foreground">Check your email to confirm, then log in.</p>
        <Button asChild className="mt-6 w-full"><Link to="/login" search={{ redirect: undefined }}>Go to login</Link></Button>
      </AuthCard>
    );

  const fields: { name: keyof In; label: string; type: string; ac: string }[] = [
    { name: "name", label: "Full name", type: "text", ac: "name" },
    { name: "email", label: "Email", type: "email", ac: "email" },
    { name: "phone", label: "Phone", type: "tel", ac: "tel" },
    { name: "password", label: "Password", type: "password", ac: "new-password" },
    { name: "confirm", label: "Confirm password", type: "password", ac: "new-password" },
  ];

  return (
    <AuthCard title="Create patient account" subtitle="Doctors and reception staff use accounts provided by the clinic.">
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
        {fields.map((f) => (
          <div key={f.name}>
            <Label htmlFor={f.name}>{f.label}</Label>
            <Input id={f.name} type={f.type} autoComplete={f.ac} {...register(f.name)} />
            <FieldError msg={errors[f.name]?.message} />
          </div>
        ))}
        <Button type="submit" className="w-full" disabled={isSubmitting}>
          {isSubmitting ? "Creating account…" : "Register"}
        </Button>
      </form>
      <p className="mt-4 text-center text-sm text-muted-foreground">
        Already registered? <Link to="/login" search={{ redirect: undefined }} className="font-semibold text-primary">Log in</Link>
      </p>
    </AuthCard>
  );
}
