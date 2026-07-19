-- PostgREST (and therefore supabase-js .rpc()) only exposes functions in
-- the public schema, not private -- the first version of this function
-- was unreachable from the edge function for exactly that reason
-- (confirmed by a live failing test call). Recreating it in public with
-- the same restrictive grants keeps it callable only by the service role,
-- while actually being reachable via RPC.

drop function if exists private.notification_recipient_emails(uuid, uuid);

create or replace function public.notification_recipient_emails(target_property_id uuid, target_department_id uuid)
returns table(email text)
language sql
stable
security definer
set search_path to ''
as $function$
  select distinct u.email
  from public.property_staff ps
  join auth.users u on u.id = ps.user_id
  where ps.property_id = target_property_id
    and ps.active = true
    and (target_department_id is null or ps.department_id = target_department_id or ps.department_id is null)
    and u.email is not null;
$function$;

revoke all on function public.notification_recipient_emails(uuid, uuid) from public;
revoke all on function public.notification_recipient_emails(uuid, uuid) from anon;
revoke all on function public.notification_recipient_emails(uuid, uuid) from authenticated;
grant execute on function public.notification_recipient_emails(uuid, uuid) to service_role;
