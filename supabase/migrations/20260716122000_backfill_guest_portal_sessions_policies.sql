-- Backfills schema objects that exist on the live database but were never
-- created by any recorded migration. private.valid_guest_portal_tokens and
-- the guest_portal_sessions policies that depend on it are placed here,
-- right after the recorded migration 20260716121852 (which introduces
-- private.has_guest_portal_access), because
-- private.has_guest_portal_access's LANGUAGE sql body already required
-- public.guest_portal_sessions to exist by that point (created in the
-- earlier backfill migration 20260716120000). private.prepare_guest_report
-- is also placed here since it calls private.has_guest_portal_access.

create or replace function private.valid_guest_portal_tokens(
  target_property_id uuid,
  target_location_id uuid,
  supplied_property_token uuid,
  supplied_location_token uuid
)
returns boolean
language sql
stable security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.properties property
    join public.property_locations location
      on location.property_id = property.id
    where property.id = target_property_id
      and property.public_id = supplied_property_token
      and property.active = true
      and location.id = target_location_id
      and location.public_id = supplied_location_token
      and location.active = true
  );
$function$;

revoke all on function private.valid_guest_portal_tokens(uuid, uuid, uuid, uuid) from public;
grant execute on function private.valid_guest_portal_tokens(uuid, uuid, uuid, uuid) to authenticated;

drop policy if exists "Guests can claim a valid QR portal" on public.guest_portal_sessions;
create policy "Guests can claim a valid QR portal"
on public.guest_portal_sessions for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and expires_at > now()
  and expires_at <= (now() + interval '14 days')
  and private.valid_guest_portal_tokens(property_id, location_id, property_token, location_token)
);

drop policy if exists "Guests can view their portal sessions" on public.guest_portal_sessions;
create policy "Guests can view their portal sessions"
on public.guest_portal_sessions for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Guests can refresh their portal sessions" on public.guest_portal_sessions;
create policy "Guests can refresh their portal sessions"
on public.guest_portal_sessions for update
to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and private.valid_guest_portal_tokens(property_id, location_id, property_token, location_token)
);

drop policy if exists "Guests can remove their portal sessions" on public.guest_portal_sessions;
create policy "Guests can remove their portal sessions"
on public.guest_portal_sessions for delete
to authenticated
using (user_id = (select auth.uid()));

create or replace function private.prepare_guest_report()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  selected_location public.property_locations%rowtype;
  routed_department uuid;
  response_minutes integer := 10;
  escalation_minutes integer := 20;
  retention_days integer := 90;
  recent_submissions integer;
begin
  if new.location_id is not null then
    select * into selected_location
    from public.property_locations
    where id = new.location_id
      and property_id = new.property_id
      and active = true;

    if selected_location.id is null then
      raise exception 'The selected hotel location is unavailable.';
    end if;

    new.location := selected_location.name;
  end if;

  select route.department_id into routed_department
  from public.department_routes route
  where route.property_id = new.property_id
    and route.category_key = new.category_key;

  new.department_id := coalesce(routed_department, selected_location.department_id, new.department_id);

  if new.department_id is not null then
    select department.response_target_minutes, department.escalation_minutes
    into response_minutes, escalation_minutes
    from public.property_departments department
    where department.id = new.department_id
      and department.property_id = new.property_id
      and department.active = true;
  end if;

  select property.data_retention_days into retention_days
  from public.properties property
  where property.id = new.property_id;

  new.acknowledge_due_at := coalesce(new.acknowledge_due_at, now() + make_interval(mins => response_minutes));
  new.escalation_due_at := coalesce(new.escalation_due_at, now() + make_interval(mins => escalation_minutes));
  new.retention_delete_after := coalesce(new.retention_delete_after, (current_date + retention_days));

  if new.source = 'guest' then
    if new.guest_user_id <> (select auth.uid())
       or new.location_id is null
       or not private.has_guest_portal_access(new.property_id, new.location_id) then
      raise exception 'Scan a valid InnRelay hotel QR code before submitting a request.';
    end if;

    select count(*) into recent_submissions
    from private.guest_submission_events submission
    where submission.user_id = (select auth.uid())
      and submission.property_id = new.property_id
      and submission.created_at > now() - interval '10 minutes';

    if recent_submissions >= 8 then
      raise exception 'Too many requests were sent. Please wait a few minutes or call Reception.';
    end if;

    insert into private.guest_submission_events (user_id, property_id)
    values ((select auth.uid()), new.property_id);
  end if;

  return new;
end;
$function$;

drop trigger if exists prepare_guest_report on public.guest_reports;
create trigger prepare_guest_report
before insert on public.guest_reports
for each row execute function private.prepare_guest_report();
