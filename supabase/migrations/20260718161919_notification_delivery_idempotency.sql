-- Prevent browser retries, duplicate escalation calls, or a malicious caller
-- from sending the same report notification repeatedly.

create table if not exists private.notification_deliveries (
  report_id uuid not null references public.guest_reports(id) on delete cascade,
  event_type text not null check (event_type in ('created', 'escalated')),
  status text not null check (status in ('pending', 'sent', 'failed')) default 'pending',
  attempt_count integer not null default 1 check (attempt_count between 1 and 20),
  provider_id text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (report_id, event_type)
);

alter table private.notification_deliveries enable row level security;
revoke all on table private.notification_deliveries from public, anon, authenticated;

create or replace function public.claim_guest_report_notification(
  p_report_id uuid,
  p_event_type text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.role()) <> 'service_role' then
    raise exception 'Notification delivery can be claimed only by the notification service.';
  end if;

  if p_event_type not in ('created', 'escalated') then
    raise exception 'Unsupported notification event.';
  end if;

  insert into private.notification_deliveries (report_id, event_type)
  values (p_report_id, p_event_type)
  on conflict (report_id, event_type) do nothing;

  if found then return true; end if;

  update private.notification_deliveries delivery
  set status = 'pending',
      attempt_count = least(20, delivery.attempt_count + 1),
      last_error = null,
      updated_at = now()
  where delivery.report_id = p_report_id
    and delivery.event_type = p_event_type
    and (
      delivery.status = 'failed'
      or (delivery.status = 'pending' and delivery.updated_at < now() - interval '5 minutes')
    );

  return found;
end;
$$;

create or replace function public.complete_guest_report_notification(
  p_report_id uuid,
  p_event_type text,
  p_succeeded boolean,
  p_provider_id text default null,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.role()) <> 'service_role' then
    raise exception 'Notification delivery can be completed only by the notification service.';
  end if;

  update private.notification_deliveries delivery
  set status = case when p_succeeded then 'sent' else 'failed' end,
      provider_id = case when p_succeeded then left(p_provider_id, 200) else null end,
      last_error = case when p_succeeded then null else left(coalesce(p_error, 'Provider request failed'), 300) end,
      updated_at = now()
  where delivery.report_id = p_report_id
    and delivery.event_type = p_event_type;
end;
$$;

revoke all on function public.claim_guest_report_notification(uuid, text) from public, anon, authenticated;
revoke all on function public.complete_guest_report_notification(uuid, text, boolean, text, text) from public, anon, authenticated;
grant execute on function public.claim_guest_report_notification(uuid, text) to service_role;
grant execute on function public.complete_guest_report_notification(uuid, text, boolean, text, text) to service_role;

