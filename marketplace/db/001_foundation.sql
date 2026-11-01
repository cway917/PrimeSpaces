-- PrimeSpaces preliminary relational schema.
-- Do not expose this database to clients before RLS policies and tests are added.
create extension if not exists pgcrypto;

create table if not exists public.organizations (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 status text not null default 'pending' check (status in ('pending','active','suspended')),
 created_at timestamptz not null default now()
);

create table if not exists public.organization_members (
 organization_id uuid not null references public.organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check (role in ('owner','manager','staff')),
 created_at timestamptz not null default now(),
 primary key (organization_id,user_id)
);

create table if not exists public.facilities (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id),
 title text not null,
 description text,
 timezone text not null default 'America/Phoenix',
 approval_mode text not null default 'manual' check (approval_mode in ('manual','automatic')),
 status text not null default 'draft' check (status in ('draft','published','unavailable')),
 created_at timestamptz not null default now()
);

create table if not exists public.bookings (
 id uuid primary key default gen_random_uuid(),
 facility_id uuid not null references public.facilities(id),
 renter_user_id uuid not null references auth.users(id),
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 status text not null default 'draft' check (status in
 ('draft','pending_payment_authorization','pending_approval','approved_pending_capture','confirmed','completed','declined','cancelled','expired','payment_failed')),
 currency text not null default 'usd',
 amount_cents bigint check (amount_cents >= 0),
 created_at timestamptz not null default now(),
 constraint valid_booking_interval check (ends_at > starts_at)
);

create index if not exists bookings_facility_interval_idx on public.bookings (facility_id,starts_at,ends_at);
create index if not exists bookings_renter_idx on public.bookings (renter_user_id);

-- Fail closed until explicit, reviewed RLS policies are installed.
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.facilities enable row level security;
alter table public.bookings enable row level security;
