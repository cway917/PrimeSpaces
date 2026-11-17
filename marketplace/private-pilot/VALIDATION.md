# Validation

2026-11-17

- TypeScript check passed.
- Production Vinext build passed; final packaging rebuilds the exact source.
- Live Supabase transaction assertions passed (all verification mutations rolled back): manual request; automatic approval; server-side rate snapshot; 10% facility-side commission; duplicate-request idempotency; overlapping pending requests; conflicting approval rejection; cancellation releases time; capacity and opening-hour rejection; blackout enforcement; renter privacy; facility organization isolation; unauthorized finance rejection; invalid runtime token and uninvited identity rejection; listing create/edit/hide; completion timing; admin hold and review; unsupported payment action rejection; no direct table exposure.
- Supabase security advisor returned an empty findings list.
- Site access is owner-only, custom allowlist with one owner and zero external visitors.
- No payments or transfers were initiated; the database permits only payment_status=disabled and exposes no payment action.
- Browser preview confirmed the responsive page renders; live data requires hosted Sites authentication, so the preview's sign-in message is expected. Hosted browser verification follows publication.

Hosted version 1 deployed successfully. The cloud browser reached the owner-only ChatGPT sign-in gate, confirming no anonymous marketplace access. This browser has no signed-in owner session, so authenticated hosted UI writes are not claimed as verified. The read-only `/api/health` endpoint checks the deployed server-to-Supabase connection without disclosing any records.

## GitHub source and original-brand migration

- The original `assets/logo.png` is reused, with the existing navy `#0b1f3b`, header `#081c34`, teal `#28c3c2`, ice-blue surfaces and original “Unlock the potential of every space” positioning.
- No booking, pricing, membership or payment behavior changed in this migration.
- The source asset preparation script ran successfully from a clean directory without bundled image files.
- Browser preview confirmed the original logo, navy header/hero and teal typography/buttons. The preview remains unauthenticated; authenticated UI writes are not claimed as verified.
- TypeScript and the final production build are checked before source transfer/deployment.
- The repository-root homepage, CSS, script and original logo are preserved by content hash.
- Runtime credentials, environment values, database connection values, user records and generated builds are excluded from the GitHub source transfer.
- The previous deployed read-only connection check returned `connected=true`, six facilities and `paymentsEnabled=false`. Identity-less marketplace access returned HTTP 401.
