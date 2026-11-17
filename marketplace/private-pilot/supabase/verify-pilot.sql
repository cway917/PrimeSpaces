-- Run in one transaction; fixture membership, credential and booking changes roll back.
begin;
update primespaces_private.config set token_hash=encode(sha256(convert_to('verification-only','UTF8')),'hex') where id=1;
insert into primespaces_private.actors(id,email,display_name,role,organization_id) values
('qa-renter','qa-renter@example.test','QA Renter','renter',null),
('qa-renter-other','qa-other@example.test','QA Other','renter',null),
('qa-facility','qa-facility@example.test','QA Facility','facility','a1000000-0000-4000-8000-000000000001'),
('qa-admin','qa-admin@example.test','QA Admin','admin',null);
do $$
declare r jsonb; r2 jsonb; k uuid:=gen_random_uuid(); b_id uuid; b2_id uuid; n integer; err text; v_date text:=(current_date+60)::text; sample_id uuid;
begin
 -- Manual request and server-authoritative cents.
 r:=public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','book',jsonb_build_object('request_key',k,'facility_id','b1000000-0000-4000-8000-000000000001','date',v_date,'start_time','17:00','end_time','19:00','guests',20,'event_name','QA manual booking','accept_rules',true,'subtotal_cents',1));
 if r->>'status'<>'pending' or (r->>'subtotal_cents')::int<>18000 or (r->>'commission_cents')::int<>1800 or (r->>'facility_net_cents')::int<>16200 then raise exception 'FAIL pricing/manual'; end if;
 b_id:=(r->>'id')::uuid;
 r2:=public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','book',jsonb_build_object('request_key',k));
 if r2->>'id'<>r->>'id' then raise exception 'FAIL idempotency'; end if;
 -- Pending requests may overlap, but a second approval must fail.
 r2:=public.primespaces_pilot('verification-only','qa-renter-other','qa-other@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id','b1000000-0000-4000-8000-000000000001','date',v_date,'start_time','18:00','end_time','20:00','guests',10,'event_name','QA overlapping request','accept_rules',true));
 b2_id:=(r2->>'id')::uuid;
 perform public.primespaces_pilot('verification-only','qa-facility','qa-facility@example.test','QA','transition',jsonb_build_object('id',b_id,'status','approved'));
 begin
  perform public.primespaces_pilot('verification-only','qa-facility','qa-facility@example.test','QA','transition',jsonb_build_object('id',b2_id,'status','approved'));
  raise exception 'FAIL overlapping approval accepted';
 exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 -- Renter cannot approve, view others' requests, or review finance.
 begin
  perform public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','transition',jsonb_build_object('id',b2_id,'status','approved'));
  raise exception 'FAIL renter approved';
 exception when insufficient_privilege then null; end;
 r:=public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','state','{}');
 if exists(select 1 from jsonb_array_elements(r->'bookings') b where b->>'renter_id'<>'qa-renter') then raise exception 'FAIL booking privacy'; end if;
 r:=public.primespaces_pilot('verification-only','qa-facility','qa-facility@example.test','QA','state','{}');
 if exists(select 1 from jsonb_array_elements(r->'bookings') b where b->>'organization_id'<>'a1000000-0000-4000-8000-000000000001') then raise exception 'FAIL facility isolation'; end if;
 begin
  perform public.primespaces_pilot('wrong-token','qa-renter','qa-renter@example.test','QA','state','{}');
  raise exception 'FAIL invalid token accepted';
 exception when insufficient_privilege then null; end;
 begin
  perform public.primespaces_pilot('verification-only','uninvited','outsider@example.test','QA','state','{}');
  raise exception 'FAIL uninvited identity accepted';
 exception when insufficient_privilege then null; end;
 -- Cancel releases a confirmed time so another pending request can be approved.
 perform public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','transition',jsonb_build_object('id',b_id,'status','cancelled'));
 perform public.primespaces_pilot('verification-only','qa-facility','qa-facility@example.test','QA','transition',jsonb_build_object('id',b2_id,'status','approved'));
 begin
  perform public.primespaces_pilot('verification-only','qa-facility','qa-facility@example.test','QA','transition',jsonb_build_object('id',b2_id,'status','completed'));
  raise exception 'FAIL early completion';
 exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 -- Capacity and opening-hour checks cannot be bypassed with direct RPC payloads.
 begin
  perform public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id','b1000000-0000-4000-8000-000000000003','date',v_date,'start_time','09:00','end_time','11:00','guests',100,'event_name','QA invalid capacity','accept_rules',true));
  raise exception 'FAIL over capacity';
 exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 begin
  perform public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id','b1000000-0000-4000-8000-000000000003','date',v_date,'start_time','05:00','end_time','07:00','guests',10,'event_name','QA outside hours','accept_rules',true));
  raise exception 'FAIL outside opening hours';
 exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 -- Blocked intervals cannot be auto-approved.
 perform public.primespaces_pilot('verification-only','qa-admin','qa-admin@example.test','QA','add_blackout',jsonb_build_object('facility_id','b1000000-0000-4000-8000-000000000003','date',v_date,'start_time','09:00','end_time','11:00'));
 begin
  perform public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id','b1000000-0000-4000-8000-000000000003','date',v_date,'start_time','09:00','end_time','11:00','guests',10,'event_name','QA blocked','accept_rules',true));
  raise exception 'FAIL blackout accepted';
 exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 r:=public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','book',jsonb_build_object('request_key',gen_random_uuid(),'facility_id','b1000000-0000-4000-8000-000000000003','date',v_date,'start_time','12:00','end_time','14:00','guests',10,'event_name','QA automatic booking','accept_rules',true));
 if r->>'status'<>'approved' or (r->>'subtotal_cents')::int<>8000 then raise exception 'FAIL auto approval'; end if;
 -- Facility cannot access another organization's booking decisions.
 begin
  perform public.primespaces_pilot('verification-only','qa-facility','qa-facility@example.test','QA','transition',jsonb_build_object('id',r->>'id','status','completed'));
  raise exception 'FAIL cross-org access';
 exception when insufficient_privilege then null; end;
 -- Complete a past event and test finance hold/review with zero payment capability.
 update primespaces_private.bookings set starts_at=now()-interval '3 hours',ends_at=now()-interval '1 hour' where id=b2_id;
 perform public.primespaces_pilot('verification-only','qa-facility','qa-facility@example.test','QA','transition',jsonb_build_object('id',b2_id,'status','completed'));
 begin
  perform public.primespaces_pilot('verification-only','qa-renter','qa-renter@example.test','QA','review',jsonb_build_object('id',b2_id,'review','reviewed','note','QA unauthorized'));
  raise exception 'FAIL renter reviewed payout';
 exception when insufficient_privilege then null; end;
 perform public.primespaces_pilot('verification-only','qa-admin','qa-admin@example.test','QA','review',jsonb_build_object('id',b2_id,'review','held','note','QA hold for review'));
 r:=public.primespaces_pilot('verification-only','qa-admin','qa-admin@example.test','QA','review',jsonb_build_object('id',b2_id,'review','reviewed','note','QA reviewed with transfers disabled'));
 if r->>'admin_review'<>'reviewed' or r->>'payment_status'<>'disabled' then raise exception 'FAIL admin review/payment guard'; end if;
 begin
  perform public.primespaces_pilot('verification-only','qa-admin','qa-admin@example.test','QA','pay',jsonb_build_object('id',b2_id));
  raise exception 'FAIL payment action accepted';
 exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
 -- New facility, edit, unlist and manual approval configuration.
 r:=public.primespaces_pilot('verification-only','qa-admin','qa-admin@example.test','QA','save_facility',jsonb_build_object('organization_name','QA Organization','organization_kind','Private','name','QA Meeting Room','city','Phoenix','description','A verification-only facility listing for a private test.','category','Meeting room','capacity',30,'rate_cents',5000,'approval_mode','manual','amenities',jsonb_build_array('Wi-Fi'),'rules','QA rules apply.','available_days',jsonb_build_array(0,1,2,3,4,5,6),'opens_at','08:00','closes_at','20:00','listed',true));
 r2:=public.primespaces_pilot('verification-only','qa-admin','qa-admin@example.test','QA','save_facility',r||jsonb_build_object('name','QA Updated Room','listed',false));
 if r2->>'name'<>'QA Updated Room' or (r2->>'listed')::boolean then raise exception 'FAIL listing edit'; end if;
 if has_table_privilege('anon','primespaces_private.bookings','select') or has_table_privilege('authenticated','primespaces_private.bookings','select') then raise exception 'FAIL direct table exposure'; end if;
 raise notice 'PASS: manual/automatic bookings, price snapshots, 10%% commission, no renter fee, idempotency, conflict rejection, cancellation, capacity/hours/blackouts, role isolation, listing management, completion, admin holds/reviews and disabled payments';
end $$;
select 'PASS: all private marketplace database workflow assertions' as validation;
rollback;
