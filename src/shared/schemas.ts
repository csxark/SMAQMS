import { z } from "zod";

export const nameSchema = z
  .string()
  .trim()
  .min(2, "At least 2 characters")
  .max(100, "At most 100 characters")
  .regex(/^[A-Za-z .'-]+$/, "Letters, spaces and . ' - only");

export const emailSchema = z.string().trim().max(254).email("Enter a valid email").transform((v) => v.toLowerCase());

export const phoneSchema = z
  .string()
  .transform((v) => v.replace(/[\s-]/g, ""))
  .pipe(z.string().regex(/^\+?[0-9]{7,15}$/, "Enter 7-15 digits, optional leading +"));

export const passwordSchema = z
  .string()
  .min(8, "At least 8 characters")
  .max(72, "At most 72 characters")
  .regex(/[A-Za-z]/, "Include a letter")
  .regex(/[0-9]/, "Include a digit");

export const loginSchema = z.object({ email: emailSchema, password: z.string().min(1, "Required") });

export const registerSchema = z
  .object({ name: nameSchema, email: emailSchema, phone: phoneSchema, password: passwordSchema, confirm: z.string() })
  .refine((v) => v.password === v.confirm, { path: ["confirm"], message: "Passwords don't match" });

export const walkInSchema = z.object({
  name: nameSchema,
  phone: phoneSchema,
  email: z
    .string()
    .trim()
    .transform((v) => (v === "" ? null : v.toLowerCase()))
    .pipe(z.string().email("Enter a valid email").max(254).nullable()),
  doctorId: z.string().min(1, "Choose a doctor"),
});

export const longText = z.string().max(5000, "Max 5000 characters");
