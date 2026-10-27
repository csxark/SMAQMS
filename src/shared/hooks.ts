import { useCallback, useEffect, useRef, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { REALTIME_FALLBACK_POLL_MS } from "@/config/constants";
import { friendlyError } from "./errors";

export function useAsync<T>(fn: () => Promise<T>, deps: unknown[]) {
  const [state, setState] = useState<{ data: T | null; error: string | null; loading: boolean }>({
    data: null,
    error: null,
    loading: true,
  });
  const fnRef = useRef(fn);
  fnRef.current = fn;
  const run = useCallback(async (silent = false) => {
    if (!silent) setState((s) => ({ ...s, loading: true, error: null }));
    try {
      const data = await fnRef.current();
      setState({ data, error: null, loading: false });
    } catch (e) {
      setState((s) => ({ data: s.data, error: friendlyError(e), loading: false }));
    }
  }, []);
  useEffect(() => {
    void run();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return { ...state, reload: run };
}

type Table = "appointments" | "queue_entries" | "consultations";
type Change = {
  table: Table;
  eventType: string;
  new: Record<string, unknown>;
  old: Record<string, unknown>;
};

/** Subscribes to realtime changes and polls as a fallback.
 *  Also fires immediately when the tab becomes visible so switching
 *  between role windows always shows fresh data. */
export function useRealtime(tables: Table[], onChange: (c: Change | null) => void) {
  const cb = useRef(onChange);
  cb.current = onChange;
  const key = tables.join(",");
  useEffect(() => {
    const channel = supabase.channel(`rt-${key}-${Math.random().toString(36).slice(2)}`);
    for (const table of tables) {
      channel.on("postgres_changes", { event: "*", schema: "public", table }, (p) =>
        cb.current({
          table,
          eventType: p.eventType,
          new: (p.new ?? {}) as Record<string, unknown>,
          old: (p.old ?? {}) as Record<string, unknown>,
        }),
      );
    }
    channel.subscribe();

    // Periodic fallback poll (WebSocket may be unavailable with sb_publishable_ keys).
    const id = window.setInterval(() => {
      if (document.visibilityState === "visible") cb.current(null);
    }, REALTIME_FALLBACK_POLL_MS);

    // Immediately re-fetch when the user switches back to this tab.
    const onVisible = () => {
      if (document.visibilityState === "visible") cb.current(null);
    };
    document.addEventListener("visibilitychange", onVisible);

    return () => {
      window.clearInterval(id);
      document.removeEventListener("visibilitychange", onVisible);
      void supabase.removeChannel(channel);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
}
