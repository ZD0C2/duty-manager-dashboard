-- Extend the per-minute escalation sweep to also notify the routed
-- department by email when a report is newly escalated. pg_net queues
-- the request asynchronously, so a slow or failing notification never
-- blocks or fails the escalation update itself.

create or replace function private.mark_overdue_guest_reports()
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  affected_rows integer := 0;
  escalated_report record;
begin
  for escalated_report in
    update public.guest_reports
    set escalated_at = now()
    where status = 'reported'
      and acknowledged_at is null
      and escalation_due_at is not null
      and escalation_due_at <= now()
      and escalated_at is null
    returning id
  loop
    affected_rows := affected_rows + 1;
    begin
      perform net.http_post(
        url := 'https://bkwzfoleuwhnuhqzxyqo.supabase.co/functions/v1/notify-guest-report',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer sb_publishable_hWv_41IDXZ4LsWaHLFHKXA_NkDI8QTf'
        ),
        body := jsonb_build_object('report_id', escalated_report.id)
      );
    exception when others then
      -- A notification failure must not block escalation itself.
      null;
    end;
  end loop;

  return affected_rows;
end;
$function$;
