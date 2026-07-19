-- Coarse secondary abuse signal (language + timezone + user-agent family,
-- already captured in client_context, no new PII) plus a rolling per-property
-- daily ceiling. Both feed moderation_status escalation rather than a hard
-- reject, per the Stays-split review section 08/06: a determined attacker
-- can mint fresh anonymous users to dodge the per-session limit, and a
-- coordinated low-and-slow campaign can stay under the 10-minute burst
-- thresholds all day.

alter table public.guest_reports add column if not exists client_fingerprint text;

create or replace function public.submit_guest_report(p_payload jsonb)
returns public.guest_reports
language plpgsql
security definer
set search_path to ''
as $function$
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
  fingerprint_hash text;
  session_reports integer;
  location_reports integer;
  property_reports integer;
  fingerprint_reports integer;
  property_daily_reports integer;
  duplicate_report public.guest_reports%rowtype;
  created_report public.guest_reports%rowtype;
  resolved_moderation_status text;
  resolved_moderation_reason text;
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
    extensions.digest(
      lower(target_property_id::text || '|' || target_location_id::text || '|' || safe_category_key || '|' || safe_title || '|' || safe_description),
      'sha256'
    ),
    'hex'
  );

  fingerprint_hash := encode(
    extensions.digest(
      lower(
        coalesce(safe_client_context->>'language', '') || '|' ||
        coalesce(safe_client_context->>'timezone', '') || '|' ||
        coalesce(safe_client_context->>'user_agent_family', '')
      ),
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

  -- Coarse secondary key: many distinct anon guest_user_ids sharing the
  -- same language/timezone/browser-family profile against one property in
  -- a short window is consistent with one attacker minting fresh sessions.
  select count(*) into fingerprint_reports
  from public.guest_reports report
  where report.property_id = target_property_id
    and report.source = 'guest'
    and report.client_fingerprint = fingerprint_hash
    and report.created_at > now() - interval '10 minutes';

  -- Rolling 24h per-property ceiling. Generous by design -- this is a
  -- coordinated-campaign backstop, not a normal-operations limit.
  select count(*) into property_daily_reports
  from public.guest_reports report
  where report.property_id = target_property_id
    and report.source = 'guest'
    and report.created_at > now() - interval '24 hours';

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

  resolved_moderation_status := case
    when session_reports >= 5 or location_reports >= 10 then 'suspected'
    else 'normal'
  end;
  resolved_moderation_reason := case
    when session_reports >= 5 then 'High volume from this browser'
    when location_reports >= 10 then 'High volume from this QR/location'
    else null
  end;

  -- Soft path: flag for staff review instead of hard-rejecting, so a real
  -- guest never gets blocked by a same-day coincidence.
  if fingerprint_reports >= 20 and safe_urgency <> 'emergency' then
    resolved_moderation_status := 'quarantined';
    resolved_moderation_reason := 'High volume sharing the same device profile in 10 minutes';
    insert into private.guest_abuse_events (user_id, property_id, location_id, event_type, idempotency_key, content_hash, reason)
    values (current_user_id, target_property_id, target_location_id, 'fingerprint_quarantined', safe_idempotency_key, calculated_hash, '20+ reports sharing one device profile in 10 minutes');
  elsif property_daily_reports >= 300 and safe_urgency <> 'emergency' then
    resolved_moderation_status := 'quarantined';
    resolved_moderation_reason := 'Property exceeded its daily guest-request ceiling';
    insert into private.guest_abuse_events (user_id, property_id, location_id, event_type, idempotency_key, content_hash, reason)
    values (current_user_id, target_property_id, target_location_id, 'property_daily_quarantined', safe_idempotency_key, calculated_hash, '300+ reports for one property in 24 hours');
  end if;

  insert into public.guest_reports (
    property_id, location_id, guest_user_id, source, location,
    category_key, category_label, issue_code, title, description,
    urgency, guest_impact, guest_name, contact_preference, status,
    idempotency_key, content_hash, client_context, client_fingerprint,
    moderation_status, moderation_reason, abuse_score
  )
  values (
    target_property_id, target_location_id, current_user_id, 'guest', 'Pending location',
    safe_category_key, safe_category_label, safe_issue_code, safe_title, safe_description,
    safe_urgency, safe_guest_impact, safe_guest_name, safe_contact_preference, 'reported',
    safe_idempotency_key, calculated_hash, safe_client_context, fingerprint_hash,
    resolved_moderation_status, resolved_moderation_reason,
    least(100, session_reports * 10 + location_reports * 4 + property_reports)
  )
  returning * into created_report;

  return created_report;
end;
$function$;

revoke all on function public.submit_guest_report(jsonb) from public, anon;
grant execute on function public.submit_guest_report(jsonb) to authenticated;

comment on column public.guest_reports.client_fingerprint is
  'sha256 of language|timezone|user_agent_family from client_context. Coarse abuse signal only, not PII-identifying.';
