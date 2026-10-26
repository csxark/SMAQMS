export const APP_NAME = "Smart Medical Appointment & Queue Management System";
export const APP_SHORT = "SMAQMS";
export const CLINIC_TIME_ZONE = "Asia/Kolkata";
export const BOOKING_WINDOW_DAYS = 30;
export const REALTIME_FALLBACK_POLL_MS = 15000;
export const SHOW_DEMO_CREDENTIALS = true;

export const DEMO_PASSWORD = "Smaqms#2026";
export const DEMO_ACCOUNTS = [
  { role: "Doctor", name: "Dr. Aarav Mehta", email: "aarav.mehta@example.com" },
  { role: "Doctor", name: "Dr. Neha Kapoor", email: "neha.kapoor@example.com" },
  { role: "Doctor", name: "Dr. Rohan Iyer", email: "rohan.iyer@example.com" },
  { role: "Receptionist", name: "Priya Sharma", email: "priya.sharma@example.com" },
  { role: "Patient", name: "Ananya Rao", email: "ananya.rao@example.com" },
  { role: "Patient", name: "Vikram Singh", email: "vikram.singh@example.com" },
  { role: "Patient", name: "Kabir Das", email: "kabir.das@example.com" },
  { role: "Patient", name: "Meera Nair", email: "meera.nair@example.com" },
] as const;
