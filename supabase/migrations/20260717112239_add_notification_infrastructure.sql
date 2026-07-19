-- Backend for transactional email notifications (new + overdue guest
-- reports). pg_net lets the escalation cron reach the edge function with
-- no client present; the notification_recipient_emails() function is the
-- narrow, service-role-only lookup the edge function uses to find who to
-- email, since auth.users is not otherwise exposed to the API layer.

create extension if not exists pg_net;

create or replace function private.notification_recipient_emails(target_property_id uuid, target_department_id uuid)
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

revoke all on function private.notification_recipient_emails(uuid, uuid) from public;
revoke all on function private.notification_recipient_emails(uuid, uuid) from anon;
revoke all on function private.notification_recipient_emails(uuid, uuid) from authenticated;
grant execute on function private.notification_recipient_emails(uuid, uuid) to service_role;
