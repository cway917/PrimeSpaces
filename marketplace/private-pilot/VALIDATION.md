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

## Rental add-ons and guest-count clarification

- Live Supabase tests passed for facility-specific rates, three separate equipment lines, totals, 10% facility-side commission on rental plus add-ons, price snapshots, duplicate retries, unavailable options, invalid/over-limit quantities, stale quote rejection, included/free items, organization isolation, completion and admin review. All test mutations rolled back.
- Original booking workflow regression assertions passed. Security advisor returned no findings.
- Two clearly marked sample listings received illustrative catalogs. The existing real Applied Technologies listing's prices were not changed.
- Local browser verification used the production rental/editor components with isolated sample data and no booking writes. $80 rental + 3 tables at $10 + 20 chairs at $2 + $50 AV showed $200 and switched to facility approval. Facility price/quantity editing and disabling AV worked. The temporary verification route and exports were removed before packaging.
- Search shows **Number of guests** with **Enter guest count**.
- Automated email and payments remain disabled. Authenticated hosted browser submissions are not claimed as verified.
# Independent private Cloudflare hosting — November 17, 2026

- Passed TypeScript checks, the existing Sites build, the independent Cloudflare production build, and a Wrangler deployment dry run. These checks do not deploy to Carla's Cloudflare account.
- Four signed-token test groups cover valid access, missing configuration, forged identity headers, wrong issuer/audience, expiration, tampered tokens and users outside the explicit pilot email list.
- The built Worker was started locally. Unauthenticated requests with forged email/admin headers received 403 for `/`, `/signin`, `/api/marketplace`, the logo and venue images. Static assets pass through the private-access check.
- The new account adapter, original pilot regression script and equipment-pricing regression script passed against the existing Supabase project inside rolled-back fixture transactions. Account tests preserve the original owner and renter IDs, reject uninvited users and editable-metadata role escalation, restrict facility bookings, deny payout review to facilities, and reject revoked sessions, bans and unconfirmed email.
- Applied the backward-compatible database adapter and ran Supabase security advisors: no findings. Confirmed that no real Supabase Auth users were created and no payments were enabled.
- After the adapter change, the existing hosted private pilot health check returned connected=true with seven facilities and paymentsEnabled=false. An identityless marketplace request still returned 401.
- Not yet verified: the user's Cloudflare deployment, real Access login, runtime bindings and a real Supabase email/password sign-in. These require account setup and controlled end-to-end checks before DNS cutover. No domain, Site audience or payment setting was changed.

## Cloudflare stylesheet and JavaScript routing repair

Reproduced an authenticated request for the generated stylesheet returning 404 while the HTML and venue images loaded. The independent Worker now sends `/_next/static/` GET/HEAD requests directly to its ASSETS binding after verifying private Access. This preserves the private gate while avoiding the App Router static-path 404.

The production-build regression test uses local synthetic signed Access tokens and a mocked certificate endpoint, with no production secrets or real users. It verifies both marketplace and sign-in HTML, every referenced stylesheet and JavaScript entry/preload, and logo/venue images: authorized requests return 200 with appropriate MIME types; requests without Access remain 403. TypeScript and the existing Access validation tests also pass. The live signed-in browser result still requires the owner to refresh after the automatic Cloudflare deployment.
