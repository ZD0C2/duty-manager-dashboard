-- InnRelay guest-abuse controls, QR safety metadata and short-term-rental mode.
-- Apply after the multi-hotel migration.

begin;

create extension if not exists pgcrypto with schema public;

alter table public.properties
  add column if not exists property_type text not null default 'hotel';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'properties_property_type_check'
      and conrelid = 'public.properties'::regclass
  ) then
    alter table public.properties
      add constraint properties_property_type_check
      check (property_type in ('hotel', 'short_term_rental'));
  end if;
end $$;

alter table public.guest_reports
  add column if not exists idempotency_key text,
  add column if not exists content_hash text,
  add column if not exists moderation_status text not null default 'normal',
  add column if not exists moderation_reason text,
  add column if not exists duplicate_of uuid references public.guest_reports(id) on delete set null,
  add column if not exists abuse_score integer not null default 0,
  add column if not exists client_context jsonb not null default '{}'::jsonb;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'property_locations_location_type_check'
      and conrelid = 'public.property_locations'::regclass
  ) then
    alter table public.property_locations drop constraint property_locations_location_type_check;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'property_locations_location_type_check'
      and conrelid = 'public.property_locations'::regclass
  ) then
    alter table public.property_locations
      add constraint property_locations_location_type_check
      check (location_type in (
        'room','reception','bar','restaurant','gym','public_area','other',
        'entrance','living','kitchen','bathroom','bedroom','dining','laundry',
        'workspace','outdoor','parking','pool_hot_tub','shared_area','whole_property'
      ));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'guest_reports_moderation_status_check'
      and conrelid = 'public.guest_reports'::regclass
  ) then
    alter table public.guest_reports
      add constraint guest_reports_moderation_status_check
      check (moderation_status in ('normal','suspected','quarantined','confirmed_abuse','cleared'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'guest_reports_idempotency_key_length_check'
      and conrelid = 'public.guest_reports'::regclass
  ) then
    alter table public.guest_reports
      add constraint guest_reports_idempotency_key_length_check
      check (idempotency_key is null or char_length(idempotency_key) between 8 and 120);
  end if;
end $$;

create unique index if not exists guest_reports_guest_idempotency_key
  on public.guest_reports (property_id, guest_user_id, idempotency_key)
  where guest_user_id is not null and idempotency_key is not null;

create index if not exists guest_reports_content_duplicate_idx
  on public.guest_reports (property_id, location_id, guest_user_id, content_hash, created_at desc)
  where content_hash is not null;

create index if not exists guest_reports_moderation_idx
  on public.guest_reports (property_id, moderation_status, created_at desc);

create table if not exists private.guest_abuse_events (
  id bigint generated always as identity primary key,
  user_id uuid,
  property_id uuid not null,
  location_id uuid,
  event_type text not null check (char_length(event_type) between 2 and 80),
  idempotency_key text,
  content_hash text,
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists guest_abuse_events_property_created_idx
  on private.guest_abuse_events (property_id, created_at desc);
create index if not exists guest_abuse_events_user_created_idx
  on private.guest_abuse_events (user_id, property_id, created_at desc)
  where user_id is not null;
create index if not exists guest_abuse_events_location_created_idx
  on private.guest_abuse_events (property_id, location_id, created_at desc)
  where location_id is not null;

create or replace function public.submit_guest_report(p_payload jsonb)
returns public.guest_reports
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  target_property_id uuid := (p_payload->>'property_id')::uuid;
  target_location_id uuid := (p_payload->>'location_id')::uuid;
  safe_title text := left(nullif(trim(p_payload->>'title'), ''), 140);
  safe_description text := left(coalesce(p_payload->>'description', ''), 1200);
  safe_category_key text := left(nullif(trim(p_payload->>'category_key'), ''), 100);
  safe_category_label text := left(nullif(trim(p_payload->>'category_label'), ''), 140);
  safe_issue_code text := left(nullif(trim(p_payload->>'issue_code'), ''), 190);
  safe_urgency text := coalesce(nullif(p_payload->>'urgency', ''), 'normal');
  safe_guest_impact text := coalesce(nullif(p_payload->>'guest_impact', ''), 'guest_affected');
  safe_guest_name text := nullif(left(trim(coalesce(p_payload->>'guest_name', '')), 80), '');
  safe_contact_preference text := coalesce(nullif(p_payload->>'contact_preference', ''), 'app');
  safe_idempotency_key text := nullif(left(trim(coalesce(p_payload->>'idempotency_key', '')), 120), '');
  safe_client_context jsonb := coalesce(p_payload->'client_context', '{}'::jsonb);
  calculated_hash text;
  session_reports integer;
  location_reports integer;
  property_reports integer;
  duplicate_report public.guest_reports%rowtype;
  created_report public.guest_reports%rowtype;
begin
  if current_user_id is null then
    raise exception 'Start a secure guest session before sending a request.';
  end if;

  if target_property_id is null or target_location_id is null then
    raise exception 'Scan a valid InnRelay QR code before submitting a request.';
  end if;

  if not private.has_guest_portal_access(target_property_id, target_location_id) then
    raise exception 'This InnRelay QR session is not valid for the selected property or location.';
  end if;

  if safe_title is null or safe_category_key is null or safe_category_label is null or safe_issue_code is null then
    raise exception 'Choose a request category and describe the issue.';
  end if;

  if safe_urgency not in ('normal','soon','urgent','emergency') then
    safe_urgency := 'normal';
  end if;

  if safe_guest_impact not in ('none_yet','guest_affected','guest_waiting','room_out_of_order') then
    safe_guest_impact := 'guest_affected';
  end if;

  if safe_contact_preference not in ('app','room-phone','reception') then
    safe_contact_preference := 'app';
  end if;

  if char_length(safe_client_context::text) > 2000 then
    safe_client_context := '{}'::jsonb;
  end if;

  calculated_hash := encode(
    public.digest(
      lower(target_property_id::text || '|' || target_location_id::text || '|' || safe_category_key || '|' || safe_title || '|' || safe_description),
      'sha256'
    ),
    'hex'
  );

  if safe_idempotency_key is not null then
    select * into duplicate_report
    from public.guest_reports report
    where report.property_id = target_property_id
      and report.guest_user_id = current_user_id
      and report.idempotency_key = safe_idempotency_key
    order by report.created_at desc
    limit 1;
    if duplicate_report.id is not null then
      return duplicate_report;
    end if;
  end if;

  select * into duplicate_report
  from public.guest_reports report
  where report.property_id = target_property_id
    and report.location_id = target_location_id
    and report.guest_user_id = current_user_id
    and report.content_hash = calculated_hash
    and report.created_at > now() - interval '2 minutes'
  order by report.created_at desc
  limit 1;
  if duplicate_report.id is not null then
    insert into private.guest_abuse_events (user_id, property_id, location_id, event_type, idempotency_key, content_hash, reason)
    values (current_user_id, target_property_id, target_location_id, 'duplicate_merged', safe_idempotency_key, calculated_hash, 'Repeated identical request inside two minutes');
    return duplicate_report;
  end if;

  select count(*) into session_reports
  from private.guest_submission_events event
  where event.user_id = current_user_id
    and event.property_id = target_property_id
    and event.created_at > now() - interval '10 minutes';

  select count(*) into location_reports
  from public.guest_reports report
  where report.property_id = target_property_id
    and report.location_id = target_location_id
    and report.source = 'guest'
    and report.created_at > now() - interval '10 minutes';

  select count(*) into property_reports
  from public.guest_reports report
  where report.property_id = target_property_id
    and report.source = 'guest'
    and report.created_at > now() - interval '10 minutes';

  if session_reports >= 8 then
    insert into private.guest_abuse_events (user_id, property_id, location_id, event_type, idempotency_key, content_hash, reason)
    values (current_user_id, target_property_id, target_location_id, 'session_rate_limited', safe_idempotency_key, calculated_hash, '8 reports in 10 minutes');
    raise exception 'Too many requests were sent from this browser. Please wait a few minutes or contact reception/host directly.';
  end if;

  if location_reports >= 15 and safe_urgency <> 'emergency' then
    insert into private.guest_abuse_events (user_id, property_id, location_id, event_type, idempotency_key, content_hash, reason)
    values (current_user_id, target_property_id, target_location_id, 'location_burst_limited', safe_idempotency_key, calculated_hash, '15 reports for one QR/location in 10 minutes');
    raise exception 'This room or area has unusually high activity. Please contact reception/host directly if this is urgent.';
  end if;

  if property_reports >= 100 and safe_urgency <> 'emergency' then
    insert into private.guest_abuse_events (user_id, property_id, location_id, event_type, idempotency_key, content_hash, reason)
    values (current_user_id, target_property_id, target_location_id, 'property_burst_limited', safe_idempotency_key, calculated_hash, '100 reports for one property in 10 minutes');
    raise exception 'InnRelay is temporarily limiting new guest requests for this property. Please contact reception/host directly.';
  end if;

  insert into public.guest_reports (
    property_id, location_id, guest_user_id, source, location,
    category_key, category_label, issue_code, title, description,
    urgency, guest_impact, guest_name, contact_preference, status,
    idempotency_key, content_hash, client_context,
    moderation_status, moderation_reason, abuse_score
  )
  values (
    target_property_id, target_location_id, current_user_id, 'guest', 'Pending location',
    safe_category_key, safe_category_label, safe_issue_code, safe_title, safe_description,
    safe_urgency, safe_guest_impact, safe_guest_name, safe_contact_preference, 'reported',
    safe_idempotency_key, calculated_hash, safe_client_context,
    case when session_reports >= 5 or location_reports >= 10 then 'suspected' else 'normal' end,
    case when session_reports >= 5 then 'High volume from this browser'
         when location_reports >= 10 then 'High volume from this QR/location'
         else null end,
    least(100, session_reports * 10 + location_reports * 4 + property_reports)
  )
  returning * into created_report;

  return created_report;
end;
$$;

revoke all on function public.submit_guest_report(jsonb) from public, anon;
grant execute on function public.submit_guest_report(jsonb) to authenticated;

create or replace function public.resolve_guest_location(
  p_property_id uuid,
  p_location_text text
)
returns table (
  id uuid,
  property_id uuid,
  public_id uuid,
  name text,
  code text,
  location_type text,
  active boolean,
  sort_order integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalised text := lower(regexp_replace(trim(coalesce(p_location_text, '')), '^room\s+', '', 'i'));
begin
  if (select auth.uid()) is null then
    raise exception 'Start a secure guest session before changing location.';
  end if;

  if not private.has_guest_portal_access(p_property_id) then
    raise exception 'Scan a valid InnRelay QR code before changing location.';
  end if;

  return query
  select location.id, location.property_id, location.public_id, location.name, location.code,
         location.location_type, location.active, location.sort_order
  from public.property_locations location
  where location.property_id = p_property_id
    and location.active = true
    and (
      lower(location.code) = normalised
      or lower(location.name) = lower(trim(coalesce(p_location_text, '')))
      or lower(regexp_replace(location.name, '^room\s+', '', 'i')) = normalised
    )
  order by case when location.location_type = 'room' then 0 else 1 end, location.sort_order, location.name
  limit 1;

  if not found then
    raise exception 'That room or area is not active for this property.';
  end if;
end;
$$;

revoke all on function public.resolve_guest_location(uuid, text) from public, anon;
grant execute on function public.resolve_guest_location(uuid, text) to authenticated;

drop policy if exists "Staff and locked guests can view locations" on public.property_locations;
create policy "Staff and locked guests can view locations"
on public.property_locations for select to authenticated
using (
  private.is_property_staff(property_id)
  or private.has_guest_portal_access(property_id, id)
  or (
    private.has_guest_portal_access(property_id)
    and exists (
      select 1
      from public.properties property
      where property.id = property_locations.property_id
        and property.property_type = 'short_term_rental'
    )
  )
);

drop policy if exists "Signed-in users can create properties" on public.properties;
drop policy if exists "Human staff can create properties" on public.properties;
create policy "Human staff can create properties"
on public.properties for insert to authenticated
with check (
  created_by = (select auth.uid())
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false
);

drop policy if exists "Guests or staff can create permitted reports" on public.guest_reports;
drop policy if exists "Guests can create their own report" on public.guest_reports;
drop policy if exists "Staff can create property reports" on public.guest_reports;

create policy "Staff can create property reports"
on public.guest_reports for insert to authenticated
with check (private.is_property_staff(property_id));

create or replace function private.purge_guest_abuse_events()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.guest_abuse_events where created_at < now() - interval '30 days';
  delete from private.guest_submission_events where created_at < now() - interval '2 days';
end;
$$;

do $$
begin
  perform cron.schedule(
    'innrelay-purge-guest-abuse-events',
    '23 3 * * *',
    'select private.purge_guest_abuse_events();'
  );
exception
  when duplicate_object then null;
  when undefined_function then null;
end $$;

grant select, update on public.properties to authenticated;
grant select on public.property_locations to authenticated;
grant select on public.guest_reports to authenticated;

comment on column public.properties.property_type is 'hotel or short_term_rental; controls guest portal catalogue and location model.';
comment on function public.submit_guest_report(jsonb) is 'Single gateway for guest submissions with portal-token validation, idempotency, duplicate merge and abuse limits.';

commit;