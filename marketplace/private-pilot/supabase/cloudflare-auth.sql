-- Preserve the Sites credential adapter; add verified Supabase account access.
-- Business rules are shared in a private invoker function with no public grants.
begin;
create or replace function primespaces_private.dispatch_actor(p_actor text,p_email text,p_name text,p_action text,p jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare a primespaces_private.actors; f primespaces_private.facilities; b primespaces_private.bookings;
 v_start timestamptz; v_end timestamptz; v_date date; v_guests integer; v_status text; v_id uuid; v_org uuid; v_amount integer;
 v_addon_catalog jsonb; v_old_catalog jsonb; v_addons_total integer:=0; v_addon_items jsonb:='[]'::jsonb; v_requested jsonb; v_code text; v_item jsonb; v_quantity numeric; v_price integer; v_label text; v_unit text;
begin
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
revoke all on function primespaces_private.dispatch_actor(text,text,text,text,jsonb) from public,anon,authenticated;

create or replace function primespaces_private.dispatch(p_token text,p_actor text,p_email text,p_name text,p_action text,p jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if p_token is null or not exists(select 1 from primespaces_private.config where id=1 and token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex')) then raise exception 'Access denied' using errcode='42501'; end if;
 return primespaces_private.dispatch_actor(p_actor,p_email,p_name,p_action,p);
end $$;
revoke all on function primespaces_private.dispatch(text,text,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function primespaces_private.dispatch(text,text,text,text,text,jsonb) to anon;

create or replace function primespaces_private.dispatch_account(p_action text,p jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user auth.users; v_actor primespaces_private.actors; v_count integer;
begin
 if auth.uid() is null then raise exception 'Sign in is required' using errcode='42501'; end if;
 select u.* into v_user from auth.users u join auth.sessions s on s.user_id=u.id
 where u.id=auth.uid() and s.id=nullif(auth.jwt()->>'session_id','')::uuid
   and u.email_confirmed_at is not null and (u.banned_until is null or u.banned_until<now())
   and (s.not_after is null or s.not_after>now());
 if not found then raise exception 'Sign in is required' using errcode='42501'; end if;
 select count(*) into v_count from primespaces_private.actors where lower(email)=lower(v_user.email);
 if v_count>1 then raise exception 'Contact info@primespaces.org to resolve account membership' using errcode='42501'; end if;
 select * into v_actor from primespaces_private.actors where lower(email)=lower(v_user.email);
 if not found then
   -- Preserve the original configured owner bootstrap. No role comes from user metadata.
   if lower(v_user.email)<>(select lower(owner_email) from primespaces_private.config where id=1) then
     raise exception 'Your account has not been invited to the pilot' using errcode='42501';
   end if;
   return primespaces_private.dispatch_actor('supabase:'||v_user.id::text,v_user.email,v_user.email,p_action,p);
 end if;
 return primespaces_private.dispatch_actor(v_actor.id,v_user.email,v_actor.display_name,p_action,p);
end $$;
revoke all on function primespaces_private.dispatch_account(text,jsonb) from public,anon,authenticated;
grant usage on schema primespaces_private to authenticated;
grant execute on function primespaces_private.dispatch_account(text,jsonb) to authenticated;
create or replace function public.primespaces_account(p_action text,p jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select primespaces_private.dispatch_account(p_action,p); $$;
revoke all on function public.primespaces_account(text,jsonb) from public,anon,authenticated;
grant execute on function public.primespaces_account(text,jsonb) to authenticated;

commit;
