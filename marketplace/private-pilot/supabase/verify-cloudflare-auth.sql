-- Run after cloudflare-auth.sql. Every fixture and configuration change rolls back.
begin;
update primespaces_private.config set token_hash=encode(sha256(convert_to('hosting-verification-only','UTF8')),'hex') where id=1;
select set_config('primespaces_test.admin_id',(select id from primespaces_private.actors where role='admin' and lower(email)=(select lower(owner_email) from primespaces_private.config where id=1)),true);
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data,is_anonymous,is_sso_user) values
 ('cfa00000-0000-4000-8000-000000000101',(select owner_email from primespaces_private.config where id=1),now(),'{}',false,false),
 ('cfa00000-0000-4000-8000-000000000102','renter@example.test',now(),'{"role":"admin"}',false,false),
 ('cfa00000-0000-4000-8000-000000000103','uninvited-auth@example.test',now(),'{"role":"admin"}',false,false),
 ('cfa00000-0000-4000-8000-000000000104','facility-auth@example.test',now(),'{}',false,false);
insert into auth.sessions(id,user_id,created_at,updated_at) values
 ('cfa10000-0000-4000-8000-000000000101','cfa00000-0000-4000-8000-000000000101',now(),now()),
 ('cfa10000-0000-4000-8000-000000000102','cfa00000-0000-4000-8000-000000000102',now(),now()),
 ('cfa10000-0000-4000-8000-000000000103','cfa00000-0000-4000-8000-000000000103',now(),now()),
 ('cfa10000-0000-4000-8000-000000000104','cfa00000-0000-4000-8000-000000000104',now(),now());
insert into primespaces_private.actors(id,email,display_name,role,organization_id) values
 ('hosting-test-facility','facility-auth@example.test','Verification facility','facility','a1000000-0000-4000-8000-000000000001');

do $$ begin
 assert not has_function_privilege('anon','public.primespaces_account(text,jsonb)','EXECUTE'),'Anonymous account RPC access';
 assert has_function_privilege('authenticated','public.primespaces_account(text,jsonb)','EXECUTE'),'Missing authenticated grant';
 assert not has_function_privilege('authenticated','primespaces_private.dispatch_actor(text,text,text,text,jsonb)','EXECUTE'),'Direct account business-rule access';
 assert not has_table_privilege('authenticated','primespaces_private.actors','SELECT'),'Direct actor access';
end $$;

set local role anon;
do $$ declare j jsonb; begin
 j:=public.primespaces_pilot('hosting-verification-only','sample-renter','renter@example.test','Sample renter','state');
 assert j->'actor'->>'id'='sample-renter','Original Sites adapter changed identity';
 begin perform public.primespaces_pilot('incorrect-token','sample-renter','renter@example.test','Sample renter','state'); raise exception 'Wrong legacy token was accepted'; exception when insufficient_privilege then null; end;
 begin perform primespaces_private.dispatch_actor('sample-renter','renter@example.test','Sample renter','state','{}'); raise exception 'Anonymous direct business-rule access'; exception when insufficient_privilege then null; end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"cfa00000-0000-4000-8000-000000000101","role":"authenticated","session_id":"cfa10000-0000-4000-8000-000000000101"}',true);
do $$ declare j jsonb; begin
 j:=public.primespaces_account('state');
 assert j->'actor'->>'role'='admin','Owner lost admin access';
 assert j->'actor'->>'id'=current_setting('primespaces_test.admin_id'),'Owner identity changed';
 assert j->>'payments_enabled'='false','Payments enabled';
end $$;

select set_config('request.jwt.claims','{"sub":"cfa00000-0000-4000-8000-000000000102","email":"cway781@gmail.com","user_metadata":{"role":"admin"},"role":"authenticated","session_id":"cfa10000-0000-4000-8000-000000000102"}',true);
do $$ declare j jsonb; begin
 j:=public.primespaces_account('state');
 assert j->'actor'->>'id'='sample-renter','Existing renter identity changed';
 assert j->'actor'->>'role'='renter','Metadata or email claim escalated role';
 assert jsonb_array_length(j->'audit')=0,'Audit leaked';
 assert not exists(select 1 from jsonb_array_elements(j->'bookings') b where b->>'renter_id'<>'sample-renter'),'Another renter booking leaked';
end $$;

select set_config('request.jwt.claims','{"sub":"cfa00000-0000-4000-8000-000000000104","role":"authenticated","session_id":"cfa10000-0000-4000-8000-000000000104"}',true);
do $$ declare j jsonb; begin
 j:=public.primespaces_account('state');
 assert j->'actor'->>'role'='facility','Facility role lost';
 assert j->'actor'->>'organization_id'='a1000000-0000-4000-8000-000000000001','Facility organization changed';
 assert not exists(select 1 from jsonb_array_elements(j->'bookings') b where b->>'organization_id'<>'a1000000-0000-4000-8000-000000000001'),'Another facility booking leaked';
 begin perform public.primespaces_account('review','{}'); raise exception 'Facility could review payouts'; exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claims','{"sub":"cfa00000-0000-4000-8000-000000000103","role":"authenticated","session_id":"cfa10000-0000-4000-8000-000000000103"}',true);
do $$ begin
 begin perform public.primespaces_account('state'); raise exception 'Uninvited account was accepted'; exception when insufficient_privilege then null; end;
end $$;

reset role;
delete from auth.sessions where id='cfa10000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"cfa00000-0000-4000-8000-000000000102","role":"authenticated","session_id":"cfa10000-0000-4000-8000-000000000102"}',true);
do $$ begin
 begin perform public.primespaces_account('state'); raise exception 'Revoked session was accepted'; exception when insufficient_privilege then null; end;
end $$;

reset role;
update auth.users set banned_until=now()+interval '1 day' where id='cfa00000-0000-4000-8000-000000000101';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"cfa00000-0000-4000-8000-000000000101","role":"authenticated","session_id":"cfa10000-0000-4000-8000-000000000101"}',true);
do $$ begin
 begin perform public.primespaces_account('state'); raise exception 'Banned account was accepted'; exception when insufficient_privilege then null; end;
end $$;
reset role;
update auth.users set banned_until=null,email_confirmed_at=null where id='cfa00000-0000-4000-8000-000000000101';
set local role authenticated;
do $$ begin
 begin perform public.primespaces_account('state'); raise exception 'Unconfirmed account was accepted'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'Cloudflare account role, membership and session checks passed; all fixtures roll back' as verification;
rollback;
