# Marketplace architecture v0.1

## Boundaries
**Public storefront:** search and view published facilities; do not expose unpublished inventory.
**Renter portal:** identity, booking requests, payment methods, documents, history.
**Owner portal:** organization membership, facilities, calendars, pricing, approval rules, booking actions.
**Platform admin:** vetted support access, pilot onboarding, disputes and audit trail.
**Backend:** authorization, price calculation, booking transaction, payments, notifications.

## Proposed services
Next.js on managed hosting; Supabase Auth/PostgreSQL/private Storage; Stripe Connect; transactional email; error monitoring.

## Booking lifecycle
`draft -> pending_payment_authorization -> pending_approval -> approved_pending_capture -> confirmed -> completed`.
Alternate terminal outcomes: `declined`, `cancelled`, `expired`, `payment_failed`.
Automatic approval skips the human decision but **not** payment capture, availability verification or compliance checks.

**Important:** The initial schema below is a foundation, not the final reservation engine. Database overlap prevention, pricing snapshots, payment intent records, event outbox, and authorization expiry rules are mandatory before pilot.

## Security
All writes checked server-side for tenant membership and role. Enable RLS on all client-visible tables and deny access by default. Keep insurance documents in private buckets with signed URLs and retention policies. Verify Stripe webhook signatures and use unique event IDs for idempotency. Never trust client-submitted prices.

## Open decisions
Authorization expiration window and reauthorization; cancellations/refunds; insurance evidence and verification; taxes; payout timing; owner fees; legal entity/KYC; booking buffer time; time zones; facility operating hours; accessibility and support SLAs.
