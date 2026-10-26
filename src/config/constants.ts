export const APP_NAME = "Smart Medical Appointment & Queue Management System";
export const APP_SHORT = "SMAQMS";
export const CLINIC_TIME_ZONE = "Asia/Kolkata";
export const BOOKING_WINDOW_DAYS = 30;
export const REALTIME_FALLBACK_POLL_MS = 15000;
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
    name: "Dr. Rohan Iyer (Cardiologist)",
    email: "rohan.iyer@example.com",
  },
  {
    role: "Doctor",
    name: "Dr. Rajesh Kulkarni (Orthopedic Surgeon)",
    email: "rajesh.kulkarni@example.com",
  },
  {
    role: "Doctor",
    name: "Dr. Tanvi Bhatia (Pulmonologist)",
    email: "tanvi.bhatia@example.com",
  },
  {
    role: "Receptionist",
    name: "Priya Sharma",
    email: "priya.sharma@example.com",
  },
  {
    role: "Receptionist",
    name: "Amit Trivedi",
    email: "amit.trivedi@example.com",
  },
  {
    role: "Receptionist",
    name: "Sunita Rao",
    email: "sunita.rao@example.com",
  },
  {
    role: "Patient",
    name: "Ananya Rao (Completed Visit & Future Booking)",
    email: "ananya.rao@example.com",
  },
  {
    role: "Patient",
    name: "Kabir Das (In Consultation Now)",
    email: "kabir.das@example.com",
  },
  {
    role: "Patient",
    name: "Meera Nair (Waiting in Live Queue)",
    email: "meera.nair@example.com",
  },
  {
    role: "Patient",
    name: "Vikram Singh (Consultation Completed Today)",
    email: "vikram.singh@example.com",
  },
] as const;
