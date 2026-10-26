<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

## Architecture rules
- All clinic data writes go through security-definer Postgres RPCs; tables only grant SELECT to clients, so never add client insert/update/delete policies.
- Role-specific areas (/patient, /doctor, /reception) are client-only layouts guarded by `requireRole` in beforeLoad (session lives in browser storage).
- Shared reads live in src/shared/repositories.ts and RPC wrappers in src/shared/rpc.ts; routes stay thin.
- Demo/filler data is seeded by a migration (staff + patient auth users, appointments, queue, consultations).
- Shared clinic presentation lives in global semantic tokens and AppShell/AuthCard; public landing styling is separate so workspace density can evolve without altering clinical workflows.
