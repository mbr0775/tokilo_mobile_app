begin;
-- A deleted account's previously issued JWT can remain valid until expiry.
-- Request records have no auth.users foreign key, so check the live account.
create or replace function public.tokilo_account_exists()
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from auth.users u where u.id=auth.uid()); $$;
revoke all on function public.tokilo_account_exists() from public, anon;
grant execute on function public.tokilo_account_exists() to authenticated;
drop policy if exists tokilo_active_request_account on public.client_projects;
create policy tokilo_active_request_account on public.client_projects
as restrictive for all to authenticated
using ((select public.tokilo_account_exists()))
with check ((select public.tokilo_account_exists()));
commit;
