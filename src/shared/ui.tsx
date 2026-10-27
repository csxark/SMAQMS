import type { ReactNode } from "react";
import { AlertTriangle, Inbox, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import type { AppointmentStatus, ConsultationStatus, QueueStatus } from "./repositories";

type AnyStatus = AppointmentStatus | QueueStatus | ConsultationStatus;
const TONE: Record<AnyStatus, string> = {
  booked: "bg-muted text-muted-foreground",
  confirmed: "bg-info/15 text-info",
  checked_in: "bg-primary/15 text-primary",
  completed: "bg-success/15 text-success",
  cancelled: "bg-destructive/12 text-destructive",
  checkin_requested: "bg-warning/20 text-warning-foreground",
  waiting: "bg-info/15 text-info",
  in_consultation: "bg-primary/15 text-primary",
  in_progress: "bg-primary/15 text-primary",
};
const LABEL: Record<AnyStatus, string> = {
  booked: "Booked",
  confirmed: "Confirmed",
  checked_in: "Checked in",
  completed: "Completed",
  cancelled: "Cancelled",
  checkin_requested: "Check-in requested",
  waiting: "Waiting",
  in_consultation: "In consultation",
  in_progress: "In progress",
};

export function StatusBadge({ status }: { status: AnyStatus }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold",
        TONE[status],
      )}
    >
      {LABEL[status]}
    </span>
  );
}

export function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <div className="mb-8 flex flex-wrap items-end justify-between gap-3 border-b pb-6">
      <div>
        <h1 className="text-2xl font-bold text-foreground md:text-3xl">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-muted-foreground">{subtitle}</p>}
      </div>
      {action}
    </div>
  );
}

export function ListSkeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div className="space-y-3">
      {Array.from({ length: rows }).map((_, i) => (
        <Skeleton key={i} className="h-20 w-full rounded-xl" />
      ))}
    </div>
  );
}

export function EmptyState({
  title,
  hint,
  action,
}: {
  title: string;
  hint?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center border-y bg-muted/30 px-6 py-16 text-center">
      <span className="mb-4 grid size-12 place-items-center rounded-full bg-muted">
        <Inbox className="size-5 text-muted-foreground" />
      </span>
      <p className="font-semibold text-foreground">{title}</p>
      {hint && <p className="mt-1 max-w-sm text-sm text-muted-foreground">{hint}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center rounded-2xl border border-destructive/30 bg-destructive/5 px-6 py-10 text-center">
      <AlertTriangle className="mb-3 size-7 text-destructive" />
      <p className="text-sm text-foreground">{message}</p>
      <Button variant="outline" size="sm" className="mt-4" onClick={onRetry}>
        <RefreshCw /> Retry
      </Button>
    </div>
  );
}

/** Renders loading / error / empty / content consistently. */
export function AsyncView<T>({
  state,
  empty,
  isEmpty,
  children,
}: {
  state: { data: T | null; error: string | null; loading: boolean; reload: () => void };
  empty: ReactNode;
  isEmpty?: (d: T) => boolean;
  children: (d: T) => ReactNode;
}) {
  if (state.loading && state.data === null) return <ListSkeleton />;
  if (state.error && state.data === null)
    return <ErrorState message={state.error} onRetry={() => state.reload()} />;
  if (state.data === null) return <ListSkeleton />;
  if (isEmpty?.(state.data)) return <>{empty}</>;
  return <>{children(state.data)}</>;
}

export function FieldError({ msg }: { msg?: string | undefined }) {
  return msg ? <p className="mt-1 text-xs text-destructive">{msg}</p> : null;
}
