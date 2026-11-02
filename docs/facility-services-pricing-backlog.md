# Facility Services, Bundles & Local Pricing — Implementation Backlog

Status: Proposed / not implemented. Owner: PrimeSpaces product team. Target: pilot launch, subject to prioritization.
Scope: Facility-specific add-ons, enterprise oversight, and ZIP-informed suggested prices. All prices are controlled by facility owners. ALA is a potential enterprise customer, not a confirmed account.

## Product decisions
- Optional services are enabled **per facility**, not globally; unavailable services must never appear in renter checkout.
- Categories: IT/AV support, custodial/janitorial, tables and chairs, setup/breakdown; extensible catalog.
- Pricing methods: included, flat, hourly, per unit, minimum fee, mandatory. Support quantity, duration, tax treatment, deposits, and cancellation terms.
- Facility owners choose final fees. PrimeSpaces recommendations are advisory, timestamped and explainable, with no automatic rate changes.
- Enterprise admins can publish templates/defaults across campuses; authorized campus admins may override according to organization policy.
- Bundles may combine space and services with a single advertised price, but checkout and reporting retain itemized allocations.
- ZIP code is a geographic starting point, not proof of a reliable price benchmark; fallback to metro/county/state and display sample size and confidence.
- Public site may advertise potential services but must not imply all locations provide them.

## P0 — Pilot booking essentials
| ID | Story | Acceptance criteria |
|---|---|---|
| FS-01 | Facility manager configures services | Service is enabled/disabled per facility; label, description, fee model, rate, unit, minimum/maximum quantity and lead time can be saved; disabled service is absent from checkout. |
| FS-02 | Configure service availability | Support date/time availability, staffing requirements and blackout dates; unavailable services cannot be purchased. |
| FS-03 | Quote add-ons during booking | Renter sees selectable services, quantities, itemized prices and updated total before submitting; required services cannot be removed. |
| FS-04 | Freeze quoted fees | Accepted booking stores fee snapshot and currency, separate from mutable rate catalog; subsequent rate edits do not change existing bookings. |
| FS-05 | Hybrid approval | Booking request includes selected add-ons for facility approval; changes trigger re-quote and renter consent before payment. |
| FS-06 | Payment split and ledger | Separate facility rental and each service charge, discounts, taxes, platform fees, refunds and facility payouts; support split payment design and reconciliation. |
| FS-07 | Roles and audit | Enterprise admin manages templates; facility manager manages authorized location rates; log who changed prices, when and prior value. |
| FS-08 | Service fulfillment | Confirm staffing/equipment availability and assign responsible contact; show fulfillment status and cancellation policy. |

## P1 — Revenue expansion
| ID | Story | Acceptance criteria |
|---|---|---|
| FS-09 | Service bundles | Facility creates Holiday Party / HOA Meeting / Esports Birthday packages, with included services, capacity, price, restrictions and booking lead time. |
| FS-10 | Multi-campus templates | Enterprise admin publishes standard service offerings and recommended rate defaults; campuses opt in or override with traceable policy. |
| FS-11 | Revenue reporting | Revenue and margins can be reported by facility, service type, bundle, and date; separate rental vs ancillary revenue. |
| FS-12 | Search by occasion and amenities | Search can filter by intended event, service availability and equipment; listings only advertise actual offerings. |

## P2 — ZIP-informed pricing recommendations
| ID | Story | Acceptance criteria |
|---|---|---|
| PR-01 | Geographic benchmark lookup | ZIP mapped to supported metro/county/state market; fallback used when ZIP data is insufficient. |
| PR-02 | Verified benchmark dataset | Ingest lawful source data for local labor, comparable service providers and platform transaction history; retain source, observation date, unit and sample count. |
| PR-03 | Explainable recommendations | Show low/typical/high range, service unit, market, data recency, sample size, and confidence; do not show fabricated values when data is absent. |
| PR-04 | Owner control | Owner can accept, edit, dismiss or ignore recommendation; recommendation never silently overwrites an established fee. |
| PR-05 | Review cadence | Refresh benchmarks periodically; flag stale or low-confidence recommendations and record changes for audit. |

## Suggested data model
- organizations(id, name, settings)
- facilities(id, organization_id, zip_code, timezone, address, status)
- service_types(id, code, label, default_unit)
- facility_services(id, facility_id, service_type_id, enabled, fee_model, unit_price_cents, currency, min_quantity, max_quantity, lead_time_hours, required, rules_json, updated_at)
- service_availability(id, facility_service_id, start_at, end_at, capacity, blackout)
- service_bundles(id, facility_id, name, price_cents, restrictions_json, enabled)
- bundle_items(id, bundle_id, facility_service_id, included_quantity, allocated_price_cents)
- booking_line_items(id, booking_id, facility_service_id, bundle_id, quantity, unit_price_cents, total_cents, tax_cents, fee_snapshot_json)
- service_fulfillment(id, booking_line_item_id, assigned_to, status)
- market_benchmarks(id, service_type_id, geography_type, geography_code, unit, low_cents, typical_cents, high_cents, sample_count, source, observed_at, confidence)
- pricing_recommendations(id, facility_service_id, market_benchmark_id, suggested_cents, rationale, status, reviewed_by, reviewed_at)
- audit_events(id, actor_id, organization_id, facility_id, action, before_json, after_json, created_at)

Enforce tenant isolation with database row-level security, validate pricing server-side, and use transactional/idempotent checkout and webhook processing. Do not trust client-submitted totals.

## Example scenarios (illustrative, not actual rates)
1. ALA campus gym holiday party: space rental + 20 tables + 160 chairs + setup + mandatory cleaning. Confirm equipment inventory and staffing before acceptance.
2. HOA board meeting: classroom or meeting room + optional projector/AV technician + furniture arrangement.
3. Esports birthday: gaming room + equipment use + optional on-site IT support + cleaning.

## Launch validation
- One facility with no optional services; one with some; one with mandatory cleaning.
- A multi-campus organization with distinct rates and staffing constraints.
- Bundle with per-unit extras, cancellation, refund, tax and split-payment edge cases.
- ZIP without adequate comparable data must display “benchmark unavailable,” not invented pricing.
- Test renter consent to price changes after approval.

## Dependencies and open decisions
- Confirm existing booking/payment schema and chosen payment processor before implementation.
- Determine whether optional services are supplied by the facility or third parties, and who is merchant of record.
- Confirm local sales-tax rules and insurance/liability coverage for service providers.
- Obtain benchmark data sources and rights before enabling market pricing guidance.
- Confirm organization policy for campus overrides, minimum charges and staff overtime.
- Validate actual ALA interest and service inventories before presenting them as listings.
