begin;

-- Private chat files; public showcase media stays in tokilo-media.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('chat-attachments', 'chat-attachments', false, 10485760,
  array['image/jpeg','image/png','image/webp','image/gif'])
on conflict(id) do update set public=false, file_size_limit=10485760,
  allowed_mime_types=excluded.allowed_mime_types;
alter table public.messages add column if not exists attachment_bucket text;

create or replace function public.tokilo_can_read_attachment(p_path text)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (
    select 1 from public.conversations c
    where c.id::text=(storage.foldername(p_path))[2]
      and (c.client_id=auth.uid() or public.tokilo_support_admin())
  );
$$;
revoke all on function public.tokilo_can_read_attachment(text) from public;
grant execute on function public.tokilo_can_read_attachment(text) to anon, authenticated;
drop policy if exists tokilo_private_attachment_boundary on storage.objects;
create policy tokilo_private_attachment_boundary on storage.objects as restrictive
for all to anon, authenticated
using (bucket_id <> 'chat-attachments' or public.tokilo_can_read_attachment(name))
with check (bucket_id <> 'chat-attachments' or public.tokilo_can_read_attachment(name));
drop policy if exists tokilo_private_attachment_read on storage.objects;
create policy tokilo_private_attachment_read on storage.objects for select to authenticated
using (bucket_id='chat-attachments' and public.tokilo_can_read_attachment(name));
drop policy if exists tokilo_private_attachment_insert on storage.objects;
create policy tokilo_private_attachment_insert on storage.objects for insert to authenticated
with check (bucket_id='chat-attachments' and (storage.foldername(name))[1]=auth.uid()::text
  and public.tokilo_can_read_attachment(name));
drop policy if exists tokilo_private_attachment_delete on storage.objects;
create policy tokilo_private_attachment_delete on storage.objects for delete to authenticated
using (bucket_id='chat-attachments' and (storage.foldername(name))[1]=auth.uid()::text
  and public.tokilo_can_read_attachment(name));

-- Stop ordinary customers from altering company media through old broad policies.
drop policy if exists tokilo_public_media_insert_boundary on storage.objects;
create policy tokilo_public_media_insert_boundary on storage.objects as restrictive for insert to anon, authenticated
with check (bucket_id <> 'tokilo-media' or (public.tokilo_support_admin() and name not like 'chat-attachments/%'));
drop policy if exists tokilo_public_media_update_boundary on storage.objects;
create policy tokilo_public_media_update_boundary on storage.objects as restrictive for update to anon, authenticated
using (bucket_id <> 'tokilo-media' or (public.tokilo_support_admin() and name not like 'chat-attachments/%'))
with check (bucket_id <> 'tokilo-media' or (public.tokilo_support_admin() and name not like 'chat-attachments/%'));
drop policy if exists tokilo_public_media_delete_boundary on storage.objects;
create policy tokilo_public_media_delete_boundary on storage.objects as restrictive for delete to anon, authenticated
using (bucket_id <> 'tokilo-media' or (public.tokilo_support_admin() and name not like 'chat-attachments/%'));

drop policy if exists tokilo_user_directory_boundary on public.users;
create policy tokilo_user_directory_boundary on public.users as restrictive for all to anon, authenticated
using (auth.uid() is not null and (id=auth.uid() or public.tokilo_support_admin()))
with check (auth.uid() is not null and (id=auth.uid() or public.tokilo_support_admin()));
drop policy if exists tokilo_presence_boundary on public.user_status;
create policy tokilo_presence_boundary on public.user_status as restrictive for select to anon, authenticated
using (auth.uid() is not null and (user_id=auth.uid() or public.tokilo_support_admin()
  or lower(email)='mubassirnasar@gmail.com'));
drop policy if exists tokilo_project_owner_boundary on public.client_projects;
create policy tokilo_project_owner_boundary on public.client_projects as restrictive for all to anon, authenticated
using (auth.uid() is not null and (client_id=auth.uid() or public.tokilo_support_admin()))
with check (auth.uid() is not null and (client_id=auth.uid() or public.tokilo_support_admin()));

create or replace function public.tokilo_guard_client_project()
returns trigger language plpgsql set search_path='' as $$
begin
  if auth.uid() is null or public.tokilo_support_admin() then return new; end if;
  if new.client_id<>auth.uid() or new.client_email is distinct from auth.jwt()->>'email' then
    raise exception 'Request identity must match your account.' using errcode='42501';
  end if;
  if tg_op='INSERT' then
    if new.status is distinct from 'pending' or coalesce(new.progress,0)<>0
      or new.admin_notes is not null or new.invoice_url is not null or new.invoice_label is not null
      or new.approved_at is not null or new.completed_at is not null then
      raise exception 'New requests must await review.' using errcode='42501';
    end if;
    new.created_at:=now();
  elsif (to_jsonb(new)-array['title','description','custom_notes','request_type','category','service_id','product_id','updated_at'])
    is distinct from (to_jsonb(old)-array['title','description','custom_notes','request_type','category','service_id','product_id','updated_at']) then
    raise exception 'Only Tokilo can change request review, invoice and progress fields.' using errcode='42501';
  end if;
  new.updated_at:=now();
  return new;
end; $$;
drop trigger if exists tokilo_guard_client_project on public.client_projects;
create trigger tokilo_guard_client_project before insert or update on public.client_projects
for each row execute function public.tokilo_guard_client_project();
revoke all on function public.tokilo_guard_client_project() from public, anon, authenticated;

-- Likes expose counts and your own state, not the customer directory.
create or replace function public.tokilo_feed_like_counts(p_post_ids text[])
returns table(post_id text, like_count bigint, is_liked boolean)
language sql stable security definer set search_path='' as $$
  select l.post_id::text, count(*), bool_or(l.user_id=auth.uid())
  from public.feed_likes l where auth.uid() is not null and l.post_id::text=any(p_post_ids[1:100])
  group by l.post_id;
$$;
revoke all on function public.tokilo_feed_like_counts(text[]) from public, anon;
grant execute on function public.tokilo_feed_like_counts(text[]) to authenticated;
drop policy if exists tokilo_like_identity_boundary on public.feed_likes;
create policy tokilo_like_identity_boundary on public.feed_likes as restrictive for select to anon, authenticated
using (auth.uid() is not null and (user_id=auth.uid() or public.tokilo_support_admin()));

create or replace function public.tokilo_send_image(p_conversation_id uuid, p_message_id uuid,
  p_path text, p_name text, p_mime_type text)
returns setof public.messages language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); admin boolean:=public.tokilo_support_admin();
  thread public.conversations; result public.messages;
begin
  if caller is null then raise exception 'Sign in to send an image.' using errcode='42501'; end if;
  if p_message_id is null or p_name is null or length(p_name)>200
    or p_mime_type not in ('image/jpeg','image/png','image/webp','image/gif')
    or (storage.foldername(p_path))[1] is distinct from caller::text
    or (storage.foldername(p_path))[2] is distinct from p_conversation_id::text then
    raise exception 'Invalid attachment.' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text,0));
  select * into thread from public.conversations where id=p_conversation_id for update;
  if not found or (thread.client_id<>caller and not admin) then
    raise exception 'Conversation is unavailable.' using errcode='42501';
  end if;
  select * into result from public.messages where id=p_message_id;
  if found then
    if result.sender_id<>caller or result.conversation_id<>p_conversation_id
      or result.attachment_path is distinct from p_path or result.message_type<>'image' then
      raise exception 'Message identifier is already in use.' using errcode='42501';
    end if;
    return next result; return;
  end if;
  if not exists(select 1 from storage.objects where bucket_id='chat-attachments' and name=p_path) then
    raise exception 'Upload the attachment first.' using errcode='22023';
  end if;
  if (select count(*) from public.messages where sender_id=caller and created_at>now()-interval '1 minute')>=30 then
    raise exception 'Please wait before sending more messages.' using errcode='P0001';
  end if;
  insert into public.messages(id,conversation_id,sender_id,sender_name,sender_role,content,message_type,
    attachment_bucket,attachment_path,attachment_name,attachment_mime_type,is_read)
  values(p_message_id,p_conversation_id,caller,left(coalesce(auth.jwt()->'user_metadata'->>'full_name',auth.jwt()->>'email','Customer'),80),
    case when admin then 'admin' else 'client' end,'Image attached','image','chat-attachments',p_path,p_name,p_mime_type,false)
  returning * into result;
  update public.conversations set last_message='Image attached',last_message_at=result.created_at,
    is_read_admin=admin,is_read_client=not admin where id=p_conversation_id;
  return next result;
end; $$;
revoke all on function public.tokilo_send_image(uuid,uuid,text,text,text) from public, anon;
grant execute on function public.tokilo_send_image(uuid,uuid,text,text,text) to authenticated;

create or replace function public.tokilo_guard_attachment_bucket()
returns trigger language plpgsql set search_path='' as $$
begin
  if auth.uid() is not null and new.attachment_bucket is distinct from old.attachment_bucket then
    raise exception 'Attachment identity cannot be changed.' using errcode='42501';
  end if;
  return new;
end; $$;
drop trigger if exists tokilo_guard_attachment_bucket on public.messages;
create trigger tokilo_guard_attachment_bucket before update on public.messages
for each row execute function public.tokilo_guard_attachment_bucket();
revoke all on function public.tokilo_guard_attachment_bucket() from public, anon, authenticated;

-- Server-only deletion helpers. Neither accepts customer-supplied identity.
create or replace function public.tokilo_account_deletion_files(p_user_id uuid)
returns table(bucket_id text, path text) language plpgsql security definer set search_path='' as $$
begin
  if auth.role() is distinct from 'service_role' then raise exception 'Server only.' using errcode='42501'; end if;
  return query select o.bucket_id::text,o.name::text from storage.objects o
  where coalesce(to_jsonb(o)->>'owner_id',to_jsonb(o)->>'owner')=p_user_id::text
    or (o.bucket_id='chat-attachments' and ((storage.foldername(o.name))[1]=p_user_id::text
      or exists(select 1 from public.conversations c
      where c.client_id=p_user_id and c.id::text=(storage.foldername(o.name))[2])))
    or (o.bucket_id='tokilo-media' and o.name like 'chat-attachments/%' and exists(
      select 1 from public.conversations c where c.client_id=p_user_id and c.id::text=(storage.foldername(o.name))[3]));
end; $$;
create or replace function public.tokilo_delete_account_data(p_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.role() is distinct from 'service_role' or p_user_id is null then
    raise exception 'Server only.' using errcode='42501';
  end if;
  if exists(select 1 from auth.users where id=p_user_id and lower(email)='mubassirnasar@gmail.com') then
    raise exception 'Administrator deletion requires a verified support request.' using errcode='42501';
  end if;
  delete from public.project_notifications where recipient_id=p_user_id
    or project_id in (select id from public.client_projects where client_id=p_user_id);
  delete from public.client_projects where client_id=p_user_id;
  delete from public.orders where user_id=p_user_id;
  delete from public.messages where sender_id=p_user_id
    or conversation_id in (select id from public.conversations where client_id=p_user_id);
  delete from public.conversations where client_id=p_user_id;
  delete from public.notifications where user_id=p_user_id;
  delete from public.notification_reads where user_id=p_user_id;
  delete from public.feed_likes where user_id=p_user_id;
  delete from public.user_push_tokens where user_id=p_user_id;
  delete from public.user_status where user_id=p_user_id;
  delete from public.profiles where id=p_user_id;
  delete from public.users where id=p_user_id;
  delete from public.projects where user_id=p_user_id;
end; $$;
revoke all on function public.tokilo_account_deletion_files(uuid), public.tokilo_delete_account_data(uuid) from public, anon, authenticated;
grant execute on function public.tokilo_account_deletion_files(uuid), public.tokilo_delete_account_data(uuid) to service_role;
notify pgrst, 'reload schema';
commit;
