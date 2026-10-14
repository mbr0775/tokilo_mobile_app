-- Append to migration 005 in place of COMMIT; all changes are rolled back.
select set_config('request.jwt.claims','{"role":"authenticated","sub":"ee000000-0000-4000-8000-999999999999","email":"deleted-fixture@example.test"}',true);
set local role authenticated;
do $$
begin
  if public.tokilo_account_exists() then raise exception 'Deleted identity is active'; end if;
  begin
    insert into public.client_projects(client_id,client_email,client_name,request_type,title,description,status,progress)
    values ('ee000000-0000-4000-8000-999999999999','deleted-fixture@example.test','Deleted fixture','software','Deleted JWT test','Rollback fixture','pending',0);
    raise exception 'Deleted identity can create a new request';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'Deleted JWT cannot recreate client requests; all changes rolled back' as result;
rollback;
