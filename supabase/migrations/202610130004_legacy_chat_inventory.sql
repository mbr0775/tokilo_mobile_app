begin;
create or replace function public.tokilo_legacy_chat_files()
returns table(path text) language plpgsql security definer set search_path='' as $$
begin
  if auth.role() is distinct from 'service_role' then raise exception 'Server only.' using errcode='42501'; end if;
  return query select o.name::text from storage.objects o
    where o.bucket_id='tokilo-media' and o.name like 'chat-attachments/%';
end; $$;
revoke all on function public.tokilo_legacy_chat_files() from public,anon,authenticated;
grant execute on function public.tokilo_legacy_chat_files() to service_role;
notify pgrst,'reload schema';
commit;
