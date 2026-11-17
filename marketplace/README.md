# PrimeSpaces marketplace

## Working private pilot

The working application source is in [private-pilot/](private-pilot/README.md), using the original PrimeSpaces logo and navy/teal brand. It includes searchable spaces, availability, booking requests, per-facility manual/automatic approval, the 10% facility-side commission, monthly statements and admin review.

The existing private application host remains authenticated and owner-only. GitHub Pages continues to serve the separate marketing homepage. Payments and transfers are disabled. A GitHub source push does not automatically deploy the private application. Build and synchronize the application through its existing private Sites deployment workflow.

The original repository-root `index.html`, `styles.css`, `script.js` and `assets/logo.png` are preserved.

## Earlier foundation and future paid-platform plan

The notes below describe the earlier scaffold and planned paid platform. They are not active payment behavior or instructions to reapply migrations to the existing project. Follow the [private-pilot README](private-pilot/README.md) for the current implementation.

This directory is an isolated starting point for the booking marketplace. The existing GitHub Pages marketing site at the repository root remains unchanged.

## Architecture
- Web: Next.js App Router with TypeScript, deployed to an application host (not GitHub Pages).
- Data/auth: Supabase PostgreSQL, Auth and private Storage.
- Payments: Stripe Connect with server-side authorization, capture, refund and payout webhooks.
- Messaging: transactional email provider with queued delivery.
- Availability: database-enforced non-overlapping holds and reservations.

## Setup
1. Create a Next.js TypeScript application in this directory (do not replace the repository-root static site).
2. Provision separate Supabase development, staging and production projects.
3. Apply the migration in `db/001_foundation.sql` after security review.
4. Implement server-only reservation and payment services. Never expose service-role keys or Stripe secret keys in browser code.
5. Implement and test RLS policies before exposing authenticated database APIs.

## Decision records
- Pilot with selected facility owners and real transactions.
- Per-facility approval policy: manual or automatic.
- Card payment authorized at booking request, captured only after approval.
- Authorization expiry and failed capture must be handled explicitly. Do not confirm an unpaid booking.
- No real payments until legal, insurance, refund and payout requirements are approved.

## Next engineering tasks
1. Bootstrap app and CI, secret scanning, type checks and tests.
2. Define tenant membership authorization and RLS tests.
3. Implement transactional booking holds and overlap exclusion.
4. Implement Stripe payment intent and webhook state machine with idempotency.
5. Build renter/owner dashboards and booking workflows.
6. End-to-end tests for overlapping requests, expiry, refunds, and retries.
