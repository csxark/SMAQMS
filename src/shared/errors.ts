const FRIENDLY: Record<string, string> = {
  SLOT_TAKEN: "That time slot was just taken. Please pick another.",
  SLOT_INVALID: "That time is not a valid slot for this doctor.",
  DATE_OUT_OF_RANGE: "Please choose a date within the next 30 days.",
  PATIENT_CONFLICT: "You already have an appointment at that time.",
  INVALID_TRANSITION: "That action isn't allowed in the current status.",
  NOT_TODAY: "Check-in is only possible on the day of the appointment.",
  QUEUE_DUPLICATE: "This patient is already in today's queue.",
  CONSULTATION_ACTIVE: "Finish your current consultation first.",
  LOCKED: "This consultation is verified and can no longer be edited.",
  FORBIDDEN: "You don't have permission to do that.",
  NOT_FOUND: "We couldn't find that record.",
  INVALID_NAME: "Please enter a valid name.",
  INVALID_PHONE: "Please enter a valid phone number.",
  TOO_LONG: "Text is too long (max 5000 characters).",
};

export function friendlyError(e: unknown): string {
  const msg =
    e && typeof e === "object" && "message" in e && typeof e.message === "string"
      ? e.message
      : String(e);
  const match = msg.match(/^([A-Z_]+):\s*(.*)$/);
  if (match) return FRIENDLY[match[1] ?? ""] ?? match[2] ?? msg;
  if (/Invalid login credentials/i.test(msg)) return "Incorrect email or password.";
  if (/already registered/i.test(msg)) return "An account with this email already exists.";
  if (/over_email_send_rate_limit|email rate limit/i.test(msg))
    return "Too many sign-up attempts. Please wait a few minutes and try again.";
  if (/rate limit|too many requests/i.test(msg))
    return "Too many requests. Please wait a moment before trying again.";
  if (/email not confirmed/i.test(msg))
    return "Please confirm your email address before logging in.";
  return msg || "Something went wrong.";
}
