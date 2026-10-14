-- Append after the migration inside a transaction; always finish with ROLLBACK.
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data)
values ('ee000000-0000-4000-8000-000000000001','authenticated','authenticated','release-a@example.test','{}','{"full_name":"Release fixture A"}'),
       ('ee000000-0000-4000-8000-000000000002','authenticated','authenticated','release-b@example.test','{}','{"full_name":"Release fixture B"}');
insert into public.conversations(id,client_id,client_name,client_email)
values ('ee100000-0000-4000-8000-000000000001','ee000000-0000-4000-8000-000000000001','Release A','release-a@example.test'),
       ('ee100000-0000-4000-8000-000000000002','ee000000-0000-4000-8000-000000000002','Release B','release-b@example.test');
insert into storage.objects(bucket_id,name)
values ('chat-attachments','ee000000-0000-4000-8000-000000000001/ee100000-0000-4000-8000-000000000001/test.png'),
       ('chat-attachments','ee000000-0000-4000-8000-000000000002/ee100000-0000-4000-8000-000000000002/test.png');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"ee000000-0000-4000-8000-000000000001","email":"release-a@example.test"}',true);
set local role authenticated;
do $$
declare first_count int; returned_id uuid;
begin
  if not public.tokilo_can_read_attachment('ee000000-0000-4000-8000-000000000001/ee100000-0000-4000-8000-000000000001/test.png') then raise exception 'Own attachment inaccessible'; end if;
  if public.tokilo_can_read_attachment('ee000000-0000-4000-8000-000000000002/ee100000-0000-4000-8000-000000000002/test.png') then raise exception 'Other customer attachment accessible'; end if;
  select count(*) into first_count from storage.objects where bucket_id='chat-attachments' and name like 'ee000000-%';
  if first_count<>1 then raise exception 'Private attachment RLS failed'; end if;
  if pg_catalog.has_function_privilege('authenticated','public.tokilo_delete_account_data(uuid)','EXECUTE') then raise exception 'Customer can run server deletion helper'; end if;
  begin
    perform public.tokilo_send_image('ee100000-0000-4000-8000-000000000002','ee200000-0000-4000-8000-000000000001',
      'ee000000-0000-4000-8000-000000000001/ee100000-0000-4000-8000-000000000002/test.png','test.png','image/png');
    raise exception 'Cross-customer image send allowed';
  exception when insufficient_privilege then null; end;
  select id into returned_id from public.tokilo_send_image('ee100000-0000-4000-8000-000000000001','ee200000-0000-4000-8000-000000000001',
    'ee000000-0000-4000-8000-000000000001/ee100000-0000-4000-8000-000000000001/test.png','test.png','image/png');
  perform public.tokilo_send_image('ee100000-0000-4000-8000-000000000001','ee200000-0000-4000-8000-000000000001',
    'ee000000-0000-4000-8000-000000000001/ee100000-0000-4000-8000-000000000001/test.png','test.png','image/png');
  select count(*) into first_count from public.messages where id=returned_id;
  if first_count<>1 then raise exception 'Image retry duplicated message'; end if;
  begin
    insert into storage.objects(bucket_id,name) values ('tokilo-media','release-customer-write.png');
    raise exception 'Customer can write public company media';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select count(*) as deletion_inventory_fixture from public.tokilo_account_deletion_files('ee000000-0000-4000-8000-000000000001');
select public.tokilo_delete_account_data('ee000000-0000-4000-8000-000000000001');
select 'Release migration compatibility and customer isolation passed; all fixtures rolled back' as result;
rollback;
