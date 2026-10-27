export const APP_NAME = "Smart Medical Appointment & Queue Management System";
export const APP_SHORT = "SMAQMS";
export const CLINIC_TIME_ZONE = "Asia/Kolkata";
export const BOOKING_WINDOW_DAYS = 30;
export const REALTIME_FALLBACK_POLL_MS = 5000;
export const SHOW_DEMO_CREDENTIALS = true;

export const DEMO_PASSWORD = "Smaqms#2026";
export const DEMO_ACCOUNTS = [
  {
    role: "Doctor",
    name: "Dr. Aarav Mehta (General Physician)",
    email: "aarav.mehta@example.com",
  },
  {
    role: "Doctor",
    name: "Dr. Neha Kapoor (Pediatrician)",
    email: "neha.kapoor@example.com",
  },
  {
    role: "Doctor",
    name: "Dr. Rohan Iyer (Cardiologist)",
    email: "rohan.iyer@example.com",
  },
  {
    role: "Doctor",
    name: "Dr. Shalini Verma (Dermatologist)",
    email: "shalini.verma@example.com",
  },
  {
    role: "Doctor",
    name: "Dr. Rajesh Kulkarni (Orthopedic Surgeon)",
    email: "rajesh.kulkarni@example.com",
  },
  {
    role: "Receptionist",
    name: "Priya Sharma",
    email: "priya.sharma@example.com",
  },
] as const;
