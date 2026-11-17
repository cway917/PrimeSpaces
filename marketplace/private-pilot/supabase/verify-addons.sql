-- Verification fixtures and all mutations roll back. No production token is used.
begin;
update primespaces_private.config set token_hash=encode(sha256(convert_to('verification-only','UTF8')),'hex') where id=1;
insert into primespaces_private.actors(id,email,display_name,role,organization_id) values
('qa-addons-admin','addons-admin@example.test','QA Add-ons Admin','admin',null),
('qa-addons-renter','addons-renter@example.test','QA Add-ons Renter','renter',null),
('qa-addons-facility','addons-facility@example.test','QA Facility','facility','a1000000-0000-4000-8000-000000000003'),
('qa-addons-other','addons-other@example.test','QA Other Facility','facility','a1000000-0000-4000-8000-000000000001');
do $$
declare cat jsonb; f jsonb; r jsonb; snapshot jsonb; saved_id uuid; key_id uuid:=gen_random_uuid(); dt text:=(current_date+75)::text; bad jsonb; e text;
begin
 cat:='{"tables":{"enabled":true,"unit_price_cents":1000,"max_quantity":10},"chairs":{"enabled":true,"unit_price_cents":200,"max_quantity":50},"av":{"enabled":true,"unit_price_cents":5000,"max_quantity":1,"description":"Projector and microphones"}}'::jsonb;
 select to_jsonb(x) into f from primespaces_private.facilities x where id='b1000000-0000-4000-8000-000000000003';
 r:=public.primespaces_pilot('verification-only','qa-addons-facility','addons-facility@example.test','QA','save_facility',f||jsonb_build_object('addon_catalog',cat));
 if (r->'addon_catalog'->'tables'->>'unit_price_cents')::integer<>1000 then raise exception 'FAIL facility prices were not saved'; end if;
 r:=public.primespaces_pilot('verification-only','qa-addons-renter','addons-renter@example.test','QA','book',jsonb_build_object('request_key',key_id,'facility_id',f->>'id','date',dt,'start_time','09:00','end_time','11:00','guests',20,'event_name','QA itemized request','accept_rules',true,'addons',jsonb_build_object('tables',3,'chairs',20,'av',1),'subtotal_cents',1,'addons_total_cents',1,'addon_items',jsonb_build_array(),'expected_total_cents',20000));
 saved_id:=(r->>'id')::uuid;snapshot:=r;
 if r->>'status'<>'pending' or (r->>'subtotal_cents')::int<>8000 or (r->>'addons_total_cents')::int<>12000 or (r->>'total_cents')::int<>20000 or (r->>'commission_cents')::int<>2000 or (r->>'facility_net_cents')::int<>18000 or jsonb_array_length(r->'addon_items')<>3 then raise exception 'FAIL itemized server quote/commission/manual approval'; end if;
 if not exists(select 1 from jsonb_array_elements(r->'addon_items') i where i->>'code'='tables' and (i->>'quantity')::int=3 and (i->>'unit_price_cents')::int=1000 and (i->>'total_cents')::int=3000) then raise exception 'FAIL table line snapshot'; end if;
 -- Catalog price changes do not alter a quote already requested.
 cat:=jsonb_set(cat,'{tables,unit_price_cents}','2000');
 perform public.primespaces_pilot('verification-only','qa-addons-facility','addons-facility@example.test','QA','save_facility',f||jsonb_build_object('addon_catalog',cat));
 select to_jsonb(b) into r from primespaces_private.bookings b where id=saved_id;
 if r->'addon_items'<>snapshot->'addon_items' or r->>'total_cents'<>snapshot->>'total_cents' then raise exception 'FAIL frozen quote changed after price edit'; end if;
 r:=public.primespaces_pilot('verification-only','qa-addons-renter','addons-renter@example.test','QA','book',jsonb_build_object('request_key',key_id));
 if r->>'id'<>saved_id::text then raise exception 'FAIL addon request retry duplicated booking'; end if;
 perform public.primespaces_pilot('verification-only','qa-addons-facility','addons-facility@example.test','QA','transition',jsonb_build_object('id',saved_id,'status','approved'));
 -- Bare rental keeps the existing automatic approval behavior.
 r:=public.primespaces_pilot('verification-only','qa-addons-renter','addons-renter@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id',f->>'id','date',dt,'start_time','12:00','end_time','14:00','guests',10,'event_name','QA bare rental','accept_rules',true));
 if r->>'status'<>'approved' or (r->>'addons_total_cents')::int<>0 or (r->>'total_cents')::int<>8000 then raise exception 'FAIL legacy rental approval/totals'; end if;
 -- Bad quantities, unknown services and client-defined prices are rejected/ignored.
 for bad in select value from jsonb_array_elements('[{"tables":-1},{"tables":1.5},{"tables":11},{"chairs":51},{"av":2},{"tables":"3"},{"unknown":1},null,[]]'::jsonb) loop
  begin
   perform public.primespaces_pilot('verification-only','qa-addons-renter','addons-renter@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id',f->>'id','date',(current_date+76)::text,'start_time','09:00','end_time','11:00','guests',10,'event_name','QA invalid extras','accept_rules',true,'addons',bad));
   raise exception 'FAIL invalid add-on quantity accepted: %',bad;
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 end loop;
 begin
  perform primespaces_private.normalize_addon_catalog('{"tables":{"enabled":true,"unit_price_cents":-1}}'::jsonb);
  raise exception 'FAIL negative catalog price';
 exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 begin
  perform public.primespaces_pilot('verification-only','qa-addons-other','addons-other@example.test','QA','save_facility',f||jsonb_build_object('addon_catalog',cat));
  raise exception 'FAIL cross-facility price edit';
 exception when insufficient_privilege then null; end;
 begin
  perform public.primespaces_pilot('verification-only','qa-addons-renter','addons-renter@example.test','QA','save_facility',f||jsonb_build_object('addon_catalog',cat));
  raise exception 'FAIL renter price edit';
 exception when insufficient_privilege then null; end;
 -- A stale renter-visible quote cannot silently increase at submission.
 begin
  perform public.primespaces_pilot('verification-only','qa-addons-renter','addons-renter@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id',f->>'id','date',(current_date+78)::text,'start_time','09:00','end_time','11:00','guests',20,'event_name','QA stale quote','accept_rules',true,'addons',jsonb_build_object('tables',3,'chairs',20,'av',1),'expected_total_cents',20000));
  raise exception 'FAIL stale quote accepted';
 exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 -- Disabled extras cannot be requested.
 cat:=jsonb_set(cat,'{av,enabled}','false');
 perform public.primespaces_pilot('verification-only','qa-addons-facility','addons-facility@example.test','QA','save_facility',f||jsonb_build_object('addon_catalog',cat));
 begin
  perform public.primespaces_pilot('verification-only','qa-addons-renter','addons-renter@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id',f->>'id','date',(current_date+76)::text,'start_time','09:00','end_time','11:00','guests',10,'event_name','QA disabled AV','accept_rules',true,'addons',jsonb_build_object('av',1)));
  raise exception 'FAIL disabled AV accepted';
 exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 -- Included items still need equipment confirmation and remain itemized at zero.
 cat:=jsonb_set(cat,'{tables,unit_price_cents}','0');
 perform public.primespaces_pilot('verification-only','qa-addons-facility','addons-facility@example.test','QA','save_facility',f||jsonb_build_object('addon_catalog',cat));
 r:=public.primespaces_pilot('verification-only','qa-addons-renter','addons-renter@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id',f->>'id','date',(current_date+77)::text,'start_time','09:00','end_time','11:00','guests',10,'event_name','QA included tables','accept_rules',true,'addons',jsonb_build_object('tables',2),'expected_total_cents',8000));
 if r->>'status'<>'pending' or (r->>'addons_total_cents')::int<>0 or jsonb_array_length(r->'addon_items')<>1 then raise exception 'FAIL included items not itemized/manual'; end if;
 -- Completion and admin finance review preserve exact totals, with no payment capability.
 update primespaces_private.bookings set starts_at=now()-interval '3 hours',ends_at=now()-interval '1 hour' where id=saved_id;
 perform public.primespaces_pilot('verification-only','qa-addons-facility','addons-facility@example.test','QA','transition',jsonb_build_object('id',saved_id,'status','completed'));
 r:=public.primespaces_pilot('verification-only','qa-addons-admin','addons-admin@example.test','QA','review',jsonb_build_object('id',saved_id,'review','reviewed','note','QA checked all add-on line items'));
 if r->>'payment_status'<>'disabled' or (r->>'facility_net_cents')::int<>18000 then raise exception 'FAIL review/payment guard'; end if;
end $$;
select 'PASS: saved facility rates, itemized rental/add-ons, immutable price snapshots, quantity validation, manual equipment approval, tenant isolation, legacy auto approval and finance totals' as validation;
rollback;
