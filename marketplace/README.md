# PrimeSpaces marketplace foundation

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
