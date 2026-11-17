# PrimeSpaces private marketplace

Working renter, facility and admin application using the original PrimeSpaces logo, navy/teal palette and marketplace positioning from `cway917/PrimeSpaces`.

Source home: `marketplace/private-pilot/` in [cway917/PrimeSpaces](https://github.com/cway917/PrimeSpaces). The repository-root GitHub Pages entry page automatically forwards visitors into this private server application.

Private deployment: https://primespaces-private-pilot.charter-one-3074.chatgpt.site

Independent private Cloudflare hosting is prepared in the same source tree. See [CLOUDFLARE.md](CLOUDFLARE.md) for the exact repository build settings, required private Access configuration, Supabase account setup and verification limits. It does not switch the live domain or enable payments.

## Run and build

Requires Node 22.13+ and npm. From this directory:

```sh
npm ci
npm run typecheck
npm run build
```

For local UI development: `npm run dev`. The portable development profile uses the starter's local mock identity; it has no production membership. The managed preview requires a real Sites identity. Do not bypass production identity to make a preview work.

`npm run assets` copies the existing logo from `../../assets/logo.png`, or downloads that same repository asset when running outside the monorepo. It downloads the illustrative venue photos only if missing. `curl` is used as a fallback on networks requiring a proxy. Generated photos and logo copies do not need to be committed. The existing root logo is the branding source.

## Hosting and privacy

Built with React, TypeScript and Vinext's Next.js-compatible App Router, compiled to a Cloudflare Worker through the included Sites integration. GitHub Pages serves the entry page and cannot run the application's server routes or protect its runtime secrets. The GitHub homepage now forwards into the private application; its runtime remains on the authenticated host.

The existing Sites project in `.openai/hosting.json` remains the owner-only authenticated host. Preserve that project's audience. Keep the application's existing private access policy. The approved GitHub homepage handoff does not grant anyone access to the application. No automatic production deployment is configured by this migration.

Sites runtime secrets: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `PRIMESPACES_SERVER_TOKEN`. Set these through the host's secret manager; never commit their values. `.env*`, `.dev.vars*`, local runtime state and build output are ignored. No service-role key is used in the browser or stored in this source.

## Supabase

The existing PrimeSpaces Supabase project is already provisioned with the pilot schema and sample records. Do not rerun schema or seed SQL against it. Files under `supabase/` are reference source and regression verification, not a startup migration runner. No database change is required for this branding/source migration.

`primespaces_private` is not exposed to the Data API. Its tables deny direct access and enable RLS. The public invoker RPC delegates to a private definer function that validates the server credential and server-supplied Sites identity on every operation. Roles and organization membership are database controlled. Only the configured owner can bootstrap as admin. Other participants require both an explicit private Site invitation and database membership; changing navigation does not grant a role.

For a separate environment, review and apply `supabase/pilot-schema.sql`, configure a new high-entropy server token through the host secret manager, and store only its SHA-256 hash and the approved owner email in `primespaces_private.config`. Sample seed data is optional and must remain visibly marked. Do not reuse a production credential in development.

## Workflows

- Search facilities by location/text, date, guests, organization kind and price. Inspect hours, amenities, rules and available intervals.
- Submit requests for manual review or reserve an available time under a facility's automatic approval policy. Rates, capacity, opening hours and conflicts are checked transactionally in Supabase. Facility locks serialize approvals and requests; request keys prevent duplicates.
- Facility teams manage listings and hours, block/unblock time, approve/decline requests, and complete past events. Renters can cancel future requests/reservations.
- Facility teams and admins can view/export consolidated monthly statements. Admins record holds, review notes and decisions in an audit trail before any future payout.
- Commission is 10% of the rental plus selected add-ons total, deducted from facility proceeds. The renter platform fee is $0. Prices use integer cents and per-booking rounding.

## Payment guard

This is an unpaid private pilot. There is no Stripe integration, payment action, connected-account onboarding, charge or transfer. The database allows only `payment_status=disabled`. Available-for-payout remains $0. Approval reserves a calendar interval, not a paid booking. Admin review records a decision and cannot release money.

## Pilot scope and validation

Arizona / America/Phoenix; single-day bookings of 1–12 hours within one year; one daily opening interval on selected weekdays; hourly rental pricing with optional tables, chairs and an AV package. Sample facilities and bookings are labeled. Taxes, deposits, other service types, insurance, agreements, notifications and payments remain future integrations. Editing opening hours does not cancel existing approved bookings.

See `VALIDATION.md` for checks actually performed and browser verification limits. The existing `marketplace/db/001_foundation.sql` and architecture notes outside this folder describe the earlier foundation/future paid platform; they do not replace the deployed private-pilot schema.

Photos are illustrative Unsplash images, not photographs of participating facilities.

## Contact and inquiries

All PrimeSpaces support, onboarding and listing inquiries go to **info@primespaces.org**. The shared destination is defined in `lib/contact.ts`. Contact links open an email draft addressed to this inbox. Automatic transactional notifications are not enabled; this update does not configure mailbox forwarding or change admin sign-in identities.

## Tables, chairs and AV charges

In **For facilities → Your spaces → Edit**, use **Optional rental add-ons** to enable tables, chairs and an AV package, set per-booking prices, quantity limits and descriptions. Tables and chairs are priced per item; AV is a flat package per booking. $0 means included equipment. Real listings start with these options disabled until the facility enters its own rates. The two sample spaces with add-ons use clearly labeled illustrative prices.

Renters select quantities in the booking form and see separate line items before requesting. Equipment selections require facility approval even when a bare space supports automatic approval. The server checks enabled options and quantity limits, calculates prices from the facility catalog, rejects stale total quotes, and freezes line items on the booking. Later rate changes do not alter existing requests. Facility approval also checks that requested equipment is still offered at the requested quantity.

`subtotal_cents` retains the space-only rental amount; `addons_total_cents` contains equipment charges and `total_cents` is their sum. The 10% commission applies to this combined total. Requests, statements, admin reviews and CSV exports retain the equipment breakdown. Payments remain disabled. Equipment inventory shared across spaces and separate staffing calendars are not implemented; the facility confirms fulfillment.

`supabase/pilot-addons.sql` records the incremental schema/function update already applied to the existing project. Do not rerun it there. `supabase/verify-addons.sql` verifies the new pricing flow inside a rolled-back transaction.
