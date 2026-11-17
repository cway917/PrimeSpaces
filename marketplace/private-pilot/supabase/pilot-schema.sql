-- Private pilot data is isolated from the existing public marketplace scaffold.
create schema if not exists primespaces_private;
revoke all on schema primespaces_private from public, anon, authenticated;
create table primespaces_private.config(id integer primary key check(id=1), token_hash text not null, owner_email text not null);
create table primespaces_private.organizations(id uuid primary key default gen_random_uuid(), name text not null, kind text not null check(kind in ('School','Church','Community','Private')));
create table primespaces_private.actors(id text primary key, email text not null, display_name text not null, role text not null check(role in ('admin','renter','facility')), organization_id uuid references primespaces_private.organizations);
create table primespaces_private.facilities(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references primespaces_private.organizations,
 name text not null check(length(name) between 3 and 160), city text not null, address text not null default '', description text not null,
 category text not null, capacity integer not null check(capacity between 1 and 10000), rate_cents integer not null check(rate_cents between 100 and 1000000),
 approval_mode text not null default 'manual' check(approval_mode in ('manual','instant')), amenities text[] not null default '{}', rules text not null default '',
 timezone text not null default 'America/Phoenix' check(timezone='America/Phoenix'), available_days integer[] not null default '{0,1,2,3,4,5,6}',
 opens_at time not null default '08:00', closes_at time not null default '22:00', image_key text not null default 'meeting',
 addon_catalog jsonb not null default '{}'::jsonb check(jsonb_typeof(addon_catalog)='object'),
 listed boolean not null default true, is_sample boolean not null default false, created_at timestamptz not null default now(), check(opens_at<closes_at)
);
create table primespaces_private.blackouts(id uuid primary key default gen_random_uuid(), facility_id uuid not null references primespaces_private.facilities, starts_at timestamptz not null, ends_at timestamptz not null, check(starts_at<ends_at));
create table primespaces_private.bookings(
 id uuid primary key default gen_random_uuid(), request_key uuid not null unique, facility_id uuid not null references primespaces_private.facilities,
 renter_id text not null references primespaces_private.actors, event_name text not null check(length(event_name) between 3 and 160), guests integer not null check(guests>0),
 notes text not null default '', starts_at timestamptz not null, ends_at timestamptz not null, status text not null default 'pending' check(status in ('pending','approved','declined','cancelled','completed')),
 rate_cents integer not null, subtotal_cents integer not null check(subtotal_cents>=0),
 addons_total_cents integer not null default 0 check(addons_total_cents>=0),
 addon_items jsonb not null default '[]'::jsonb check(jsonb_typeof(addon_items)='array' and jsonb_array_length(addon_items)<=3),
 total_cents integer generated always as (subtotal_cents+addons_total_cents) stored,
 commission_cents integer generated always as (round((subtotal_cents+addons_total_cents)*0.10)) stored,
 facility_net_cents integer generated always as (subtotal_cents+addons_total_cents-round((subtotal_cents+addons_total_cents)*0.10)) stored,
 admin_review text not null default 'unreviewed' check(admin_review in ('unreviewed','held','reviewed')), review_note text not null default '',
 payment_status text not null default 'disabled' check(payment_status='disabled'), is_sample boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(starts_at<ends_at)
);
create index on primespaces_private.facilities(organization_id);
create index on primespaces_private.bookings(facility_id,starts_at,ends_at);
create index on primespaces_private.bookings(renter_id);
create index on primespaces_private.actors(organization_id);
create index on primespaces_private.blackouts(facility_id);
create table primespaces_private.audit(id bigint generated always as identity primary key, actor_id text not null, action text not null, record_id uuid, detail text not null default '', created_at timestamptz not null default now());
alter table primespaces_private.config enable row level security;
alter table primespaces_private.organizations enable row level security;
alter table primespaces_private.actors enable row level security;
alter table primespaces_private.facilities enable row level security;
alter table primespaces_private.blackouts enable row level security;
alter table primespaces_private.bookings enable row level security;
alter table primespaces_private.audit enable row level security;
revoke all on all tables in schema primespaces_private from public,anon,authenticated;

create or replace function primespaces_private.normalize_addon_catalog(p_catalog jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_code text; v_item jsonb; v_enabled boolean; v_price numeric; v_max numeric; v_limit integer; v_result jsonb:='{}'::jsonb;
begin
 if p_catalog is null or jsonb_typeof(p_catalog)<>'object' then raise exception 'Add-on settings must be an object'; end if;
 for v_code in select jsonb_object_keys(p_catalog) loop
  if v_code not in ('tables','chairs','av') then raise exception 'Unsupported facility add-on'; end if;
 end loop;
 foreach v_code in array array['tables','chairs','av'] loop
  v_item:=coalesce(p_catalog->v_code,'{}'::jsonb);
  if jsonb_typeof(v_item)<>'object' then raise exception 'Invalid add-on settings'; end if;
  if v_item?'enabled' and jsonb_typeof(v_item->'enabled')<>'boolean' then raise exception 'Add-on availability must be true or false'; end if;
  v_enabled:=coalesce((v_item->>'enabled')::boolean,false);
  if v_item?'unit_price_cents' and (jsonb_typeof(v_item->'unit_price_cents')<>'number' or (v_item->>'unit_price_cents')!~'^[0-9]+$') then raise exception 'Add-on prices must be nonnegative whole cents'; end if;
  v_price:=coalesce((v_item->>'unit_price_cents')::numeric,0);
  if v_price<0 or v_price>(case when v_code='av' then 1000000 else 100000 end) then raise exception 'Add-on price exceeds the supported range'; end if;
  v_limit:=case when v_code='tables' then 1000 when v_code='chairs' then 10000 else 1 end;
  if v_item?'max_quantity' and (jsonb_typeof(v_item->'max_quantity')<>'number' or (v_item->>'max_quantity')!~'^[0-9]+$') then raise exception 'Add-on limits must be whole quantities'; end if;
  v_max:=coalesce((v_item->>'max_quantity')::numeric,case when v_code='tables' then 20 when v_code='chairs' then 200 else 1 end);
  if v_max<1 or v_max>v_limit then raise exception 'Add-on quantity limit is outside the supported range'; end if;
  if length(coalesce(v_item->>'description',''))>300 then raise exception 'Keep add-on descriptions under 300 characters'; end if;
  v_result:=v_result||jsonb_build_object(v_code,jsonb_build_object('enabled',v_enabled,'unit_price_cents',v_price::integer,'max_quantity',v_max::integer,'description',coalesce(v_item->>'description','')));
 end loop;
 return v_result;
end $$;
revoke all on function primespaces_private.normalize_addon_catalog(jsonb) from public,anon,authenticated;

create or replace function primespaces_private.dispatch(p_token text,p_actor text,p_email text,p_name text,p_action text,p jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a primespaces_private.actors; f primespaces_private.facilities; b primespaces_private.bookings;
 v_start timestamptz; v_end timestamptz; v_date date; v_guests integer; v_status text; v_id uuid; v_org uuid; v_amount integer;
 v_addon_catalog jsonb; v_old_catalog jsonb; v_addons_total integer:=0; v_addon_items jsonb:='[]'::jsonb; v_requested jsonb; v_code text; v_item jsonb; v_quantity numeric; v_price integer; v_label text; v_unit text;
begin
 if p_token is null or not exists(select 1 from primespaces_private.config where id=1 and token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex')) then raise exception 'Access denied' using errcode='42501'; end if;
 if p_actor is null or length(p_actor)<3 or p_email is null then raise exception 'Sign in is required' using errcode='42501'; end if;
 select * into a from primespaces_private.actors where id=p_actor;
 if not found then
   if lower(p_email)<>(select lower(owner_email) from primespaces_private.config where id=1) then raise exception 'Your account has not been invited to the pilot' using errcode='42501'; end if;
   insert into primespaces_private.actors(id,email,display_name,role) values(p_actor,p_email,coalesce(nullif(p_name,''),p_email),'admin') returning * into a;
 end if;
 if lower(a.email)<>lower(p_email) then raise exception 'Identity mismatch' using errcode='42501'; end if;
 if p_action='state' then
   return jsonb_build_object(
    'actor',to_jsonb(a),
    'organizations',coalesce((select jsonb_agg(to_jsonb(o) order by o.name) from primespaces_private.organizations o where a.role='admin' or o.id=a.organization_id),'[]'::jsonb),
    'facilities',coalesce((select jsonb_agg(to_jsonb(t) order by t.created_at,t.name) from (select sf.*,o.name organization_name,o.kind organization_kind from primespaces_private.facilities sf join primespaces_private.organizations o on o.id=sf.organization_id where sf.listed or a.role='admin' or sf.organization_id=a.organization_id) t),'[]'::jsonb),
    'blackouts',coalesce((select jsonb_agg(to_jsonb(t)) from primespaces_private.blackouts t),'[]'::jsonb),
    'reserved',coalesce((select jsonb_agg(jsonb_build_object('id',id,'facility_id',facility_id,'starts_at',starts_at,'ends_at',ends_at)) from primespaces_private.bookings where status in ('approved','completed')),'[]'::jsonb),
    'bookings',coalesce((select jsonb_agg(to_jsonb(t) order by t.created_at desc) from (select sb.*,sf.name facility_name,sf.organization_id,sf.timezone,o.name organization_name,r.display_name renter_name,r.email renter_email from primespaces_private.bookings sb join primespaces_private.facilities sf on sf.id=sb.facility_id join primespaces_private.organizations o on o.id=sf.organization_id join primespaces_private.actors r on r.id=sb.renter_id where a.role='admin' or sb.renter_id=a.id or (a.role='facility' and sf.organization_id=a.organization_id)) t),'[]'::jsonb),
    'audit',case when a.role='admin' then coalesce((select jsonb_agg(to_jsonb(t)) from (select * from primespaces_private.audit order by id desc limit 40)t),'[]'::jsonb) else '[]'::jsonb end,
    'payments_enabled',false
   );
 elsif p_action='book' then
   select * into b from primespaces_private.bookings where request_key=(p->>'request_key')::uuid;
   if found then if b.renter_id<>a.id then raise exception 'Request key already used'; end if; return to_jsonb(b); end if;
   select * into f from primespaces_private.facilities where id=(p->>'facility_id')::uuid and listed for update;
   if not found then raise exception 'Facility is not available'; end if;
   select * into b from primespaces_private.bookings where request_key=(p->>'request_key')::uuid;
   if found then if b.renter_id<>a.id then raise exception 'Request key already used'; end if; return to_jsonb(b); end if;
   v_date:=(p->>'date')::date;
   v_start:=(v_date::text||' '||(p->>'start_time'))::timestamp at time zone f.timezone;
   v_end:=(v_date::text||' '||(p->>'end_time'))::timestamp at time zone f.timezone;
   v_guests:=(p->>'guests')::integer;
   if v_start<=now() or v_start>now()+interval '365 days' or v_end-v_start<interval '1 hour' or v_end-v_start>interval '12 hours' then raise exception 'Choose a future booking of 1–12 hours, within the next year'; end if;
   if v_guests<1 or v_guests>f.capacity then raise exception 'Guest count exceeds facility capacity'; end if;
   if length(trim(coalesce(p->>'event_name','')))<3 or length(p->>'event_name')>160 or length(coalesce(p->>'notes',''))>2000 then raise exception 'Enter an event name (3–160 characters) and notes under 2,000 characters'; end if;
   if not coalesce((p->>'accept_rules')::boolean,false) then raise exception 'Accept the facility rules to continue'; end if;
   if not(extract(dow from v_date)::integer=any(f.available_days)) or (p->>'start_time')::time<f.opens_at or (p->>'end_time')::time>f.closes_at then raise exception 'This time is outside facility opening hours'; end if;
   if exists(select 1 from primespaces_private.blackouts where facility_id=f.id and starts_at<v_end and ends_at>v_start) or exists(select 1 from primespaces_private.bookings where facility_id=f.id and status in ('approved','completed') and starts_at<v_end and ends_at>v_start) then raise exception 'This time is unavailable. Please choose another time'; end if;
   v_requested:=coalesce(p->'addons','{}'::jsonb);
   if jsonb_typeof(v_requested)<>'object' then raise exception 'Add-on quantities must be an object'; end if;
   for v_code in select jsonb_object_keys(v_requested) loop
    if v_code not in ('tables','chairs','av') then raise exception 'Unsupported booking add-on'; end if;
    if jsonb_typeof(v_requested->v_code)<>'number' or (v_requested->>v_code)!~'^[0-9]+$' then raise exception 'Choose a nonnegative whole quantity for each add-on'; end if;
    v_quantity:=(v_requested->>v_code)::numeric;
    if v_quantity=0 then continue; end if;
    v_item:=f.addon_catalog->v_code;
    if v_item is null or not coalesce((v_item->>'enabled')::boolean,false) then raise exception 'This facility does not offer the selected add-on'; end if;
    if v_quantity>(v_item->>'max_quantity')::integer then raise exception 'Requested add-on quantity exceeds the facility limit'; end if;
    v_price:=(v_item->>'unit_price_cents')::integer;
    v_label:=case v_code when 'tables' then 'Tables' when 'chairs' then 'Chairs' else 'AV package' end;
    v_unit:=case v_code when 'tables' then 'table' when 'chairs' then 'chair' else 'booking' end;
    v_addon_items:=v_addon_items||jsonb_build_array(jsonb_build_object('code',v_code,'label',v_label,'unit',v_unit,'quantity',v_quantity::integer,'unit_price_cents',v_price,'total_cents',v_quantity::integer*v_price,'description',v_item->>'description'));
    v_addons_total:=v_addons_total+v_quantity::integer*v_price;
   end loop;
   -- Equipment/staffing availability is confirmed by the facility, including free extras.
   v_status:=case when f.approval_mode='instant' and jsonb_array_length(v_addon_items)=0 then 'approved' else 'pending' end;
   v_amount:=round(extract(epoch from(v_end-v_start))/3600*f.rate_cents);
   if jsonb_array_length(v_addon_items)>0 and not(p?'expected_total_cents') then raise exception 'Review the itemized quote before requesting add-ons'; end if;
   if p?'expected_total_cents' and (coalesce(p->>'expected_total_cents','')!~'^[0-9]+$' or (p->>'expected_total_cents')::numeric<>v_amount+v_addons_total) then raise exception 'The price changed. Refresh the page and review the updated quote before submitting'; end if;
   insert into primespaces_private.bookings(request_key,facility_id,renter_id,event_name,guests,notes,starts_at,ends_at,status,rate_cents,subtotal_cents,addons_total_cents,addon_items,is_sample)
   values((p->>'request_key')::uuid,f.id,a.id,trim(p->>'event_name'),v_guests,coalesce(p->>'notes',''),v_start,v_end,v_status,f.rate_cents,v_amount,v_addons_total,v_addon_items,f.is_sample) returning * into b;
   insert into primespaces_private.audit(actor_id,action,record_id,detail)values(a.id,'booking_created',b.id,v_status);
   return to_jsonb(b);
 elsif p_action='transition' then
   -- Lock facility first, consistently with booking creation, to serialize approvals.
   select * into f from primespaces_private.facilities where id=(select facility_id from primespaces_private.bookings where id=(p->>'id')::uuid) for update;
   select * into b from primespaces_private.bookings where id=(p->>'id')::uuid for update;
   if not found then raise exception 'Booking not found'; end if;
   v_status:=p->>'status';
   if v_status='cancelled' then
     if a.role<>'admin' and b.renter_id<>a.id then raise exception 'You cannot cancel this booking' using errcode='42501'; end if;
     if b.status not in ('pending','approved') or b.starts_at<=now() then raise exception 'Only future pending or approved bookings can be cancelled'; end if;
   else
     if a.role<>'admin' and (a.role<>'facility' or f.organization_id is distinct from a.organization_id) then raise exception 'Facility access required' using errcode='42501'; end if;
     if not((b.status='pending' and v_status in ('approved','declined')) or (b.status='approved' and v_status='completed')) then raise exception 'Invalid booking status change'; end if;
     if v_status='approved' then
       if b.starts_at<=now() then raise exception 'A past request cannot be approved'; end if;
       for v_item in select value from jsonb_array_elements(b.addon_items) loop
        v_code:=v_item->>'code';
        if not coalesce((f.addon_catalog->v_code->>'enabled')::boolean,false) or (v_item->>'quantity')::integer>coalesce((f.addon_catalog->v_code->>'max_quantity')::integer,0) then raise exception 'Requested equipment is no longer offered in this quantity'; end if;
       end loop;
       if b.guests>f.capacity or not(extract(dow from (b.starts_at at time zone f.timezone))::integer=any(f.available_days)) or (b.starts_at at time zone f.timezone)::time<f.opens_at or (b.ends_at at time zone f.timezone)::time>f.closes_at then raise exception 'The request no longer fits the facility hours or capacity'; end if;
       if exists(select 1 from primespaces_private.blackouts where facility_id=f.id and starts_at<b.ends_at and ends_at>b.starts_at) or exists(select 1 from primespaces_private.bookings where facility_id=f.id and id<>b.id and status in ('approved','completed') and starts_at<b.ends_at and ends_at>b.starts_at) then raise exception 'This time is already reserved or blocked'; end if;
     end if;
     if v_status='completed' and b.ends_at>now() then raise exception 'Complete a booking after its end time'; end if;
   end if;
   update primespaces_private.bookings set status=v_status,updated_at=now() where id=b.id returning * into b;
   insert into primespaces_private.audit(actor_id,action,record_id,detail) values(a.id,'booking_'||v_status,b.id,coalesce(p->>'note',''));
   return to_jsonb(b);
 elsif p_action='save_facility' then
   if a.role not in ('admin','facility') then raise exception 'Facility access required' using errcode='42501'; end if;
   v_id:=nullif(p->>'id','')::uuid;
   if v_id is not null then
     select * into f from primespaces_private.facilities where id=v_id for update;
     if not found or (a.role<>'admin' and f.organization_id is distinct from a.organization_id) then raise exception 'Facility access required' using errcode='42501'; end if;
     v_org:=f.organization_id;
   else
     v_org:=a.organization_id;
     if a.role='admin' then
       if length(trim(coalesce(p->>'organization_name','')))<3 then raise exception 'Enter your organization name'; end if;
       insert into primespaces_private.organizations(name,kind) values(trim(p->>'organization_name'),p->>'organization_kind') returning id into v_org;
     end if;
   end if;
   if length(trim(coalesce(p->>'name','')))<3 or length(trim(coalesce(p->>'city','')))<2 or length(coalesce(p->>'description',''))<20 or length(coalesce(p->>'rules',''))<5 then raise exception 'Complete the facility name, city, description and rules'; end if;
   if not(p->>'category'=any(array['Gymnasium','Meeting room','Auditorium','Classroom','Event hall','Sports field'])) then raise exception 'Choose a valid space type'; end if;
   if jsonb_array_length(p->'available_days')<1 then raise exception 'Choose at least one available day'; end if;
   v_old_catalog:=coalesce(f.addon_catalog,'{}'::jsonb);
   v_addon_catalog:=primespaces_private.normalize_addon_catalog(case when p?'addon_catalog' then p->'addon_catalog' else v_old_catalog end);
   if v_id is null then
     insert into primespaces_private.facilities(organization_id,name,city,address,description,category,capacity,rate_cents,approval_mode,amenities,rules,available_days,opens_at,closes_at,image_key,listed,addon_catalog)
     values(v_org,trim(p->>'name'),trim(p->>'city'),coalesce(p->>'address',''),p->>'description',p->>'category',(p->>'capacity')::integer,(p->>'rate_cents')::integer,p->>'approval_mode',array(select jsonb_array_elements_text(p->'amenities')),p->>'rules',array(select jsonb_array_elements_text(p->'available_days')::integer),(p->>'opens_at')::time,(p->>'closes_at')::time,coalesce(p->>'image_key','meeting'),coalesce((p->>'listed')::boolean,true),v_addon_catalog) returning * into f;
   else
     update primespaces_private.facilities set name=trim(p->>'name'),city=trim(p->>'city'),address=coalesce(p->>'address',''),description=p->>'description',category=p->>'category',capacity=(p->>'capacity')::integer,rate_cents=(p->>'rate_cents')::integer,approval_mode=p->>'approval_mode',amenities=array(select jsonb_array_elements_text(p->'amenities')),rules=p->>'rules',available_days=array(select jsonb_array_elements_text(p->'available_days')::integer),opens_at=(p->>'opens_at')::time,closes_at=(p->>'closes_at')::time,listed=(p->>'listed')::boolean,addon_catalog=v_addon_catalog where id=v_id returning * into f;
   end if;
   insert into primespaces_private.audit(actor_id,action,record_id,detail) values(a.id,'facility_saved',f.id,jsonb_build_object('add_ons_before',v_old_catalog,'add_ons_after',v_addon_catalog)::text);
   return to_jsonb(f);
 elsif p_action in ('add_blackout','remove_blackout') then
   select * into f from primespaces_private.facilities where id=(p->>'facility_id')::uuid for update;
   if not found or (a.role<>'admin' and (a.role<>'facility' or f.organization_id is distinct from a.organization_id)) then raise exception 'Facility access required' using errcode='42501'; end if;
   if p_action='remove_blackout' then delete from primespaces_private.blackouts where id=(p->>'id')::uuid and facility_id=f.id;
   else
     v_start:=((p->>'date')||' '||(p->>'start_time'))::timestamp at time zone f.timezone;
     v_end:=((p->>'date')||' '||(p->>'end_time'))::timestamp at time zone f.timezone;
     if v_end<=v_start or v_start<=now() then raise exception 'Choose a future block with an end after its start'; end if;
     if exists(select 1 from primespaces_private.bookings where facility_id=f.id and status in ('approved','completed') and starts_at<v_end and ends_at>v_start) then raise exception 'A confirmed reservation overlaps this block'; end if;
     insert into primespaces_private.blackouts(facility_id,starts_at,ends_at)values(f.id,v_start,v_end);
   end if;
   insert into primespaces_private.audit(actor_id,action,record_id)values(a.id,p_action,f.id);
   return jsonb_build_object('ok',true);
 elsif p_action='review' then
   if a.role<>'admin' then raise exception 'Admin access required' using errcode='42501'; end if;
   select * into b from primespaces_private.bookings where id=(p->>'id')::uuid for update;
   if not found or b.status<>'completed' then raise exception 'Only completed bookings can be reviewed'; end if;
   if p->>'review' not in ('held','reviewed') or length(trim(coalesce(p->>'note','')))<3 then raise exception 'Add a review note'; end if;
   update primespaces_private.bookings set admin_review=p->>'review',review_note=left(p->>'note',1000),updated_at=now() where id=b.id returning * into b;
   insert into primespaces_private.audit(actor_id,action,record_id,detail)values(a.id,'admin_'||(p->>'review'),b.id,p->>'note');
   return to_jsonb(b);
 else raise exception 'Unsupported action';
 end if;
end $$;
revoke all on function primespaces_private.dispatch(text,text,text,text,text,jsonb) from public,anon,authenticated;
-- Only this narrow RPC can be reached with a publishable key. It requires a separate
-- 256-bit server credential; visitor identity is supplied by the private Sites server.
create function public.primespaces_pilot(p_token text,p_actor text,p_email text,p_name text,p_action text,p jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select primespaces_private.dispatch(p_token,p_actor,p_email,p_name,p_action,p); $$;
revoke all on function public.primespaces_pilot(text,text,text,text,text,jsonb) from public,anon,authenticated;
grant usage on schema primespaces_private to anon;
grant execute on function primespaces_private.dispatch(text,text,text,text,text,jsonb) to anon;
grant execute on function public.primespaces_pilot(text,text,text,text,text,jsonb) to anon;

create policy deny_direct_access on primespaces_private.config for all to anon,authenticated using(false) with check(false);

create policy deny_direct_access on primespaces_private.organizations for all to anon,authenticated using(false) with check(false);

create policy deny_direct_access on primespaces_private.actors for all to anon,authenticated using(false) with check(false);

create policy deny_direct_access on primespaces_private.facilities for all to anon,authenticated using(false) with check(false);

create policy deny_direct_access on primespaces_private.blackouts for all to anon,authenticated using(false) with check(false);

create policy deny_direct_access on primespaces_private.bookings for all to anon,authenticated using(false) with check(false);

create policy deny_direct_access on primespaces_private.audit for all to anon,authenticated using(false) with check(false);
