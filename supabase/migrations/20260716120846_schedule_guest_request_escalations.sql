create extension if not exists pg_cron with schema pg_catalog;

create or replace function private.mark_overdue_guest_reports()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_rows integer;
begin
  update public.guest_reports
  set escalated_at = now()
  where status = 'reported'
    and acknowledged_at is null
    and escalation_due_at is not null
    and escalation_due_at <= now()
    and escalated_at is null;

  get diagnostics affected_rows = row_count;
  return affected_rows;
end;
$$;

revoke all on function private.mark_overdue_guest_reports() from public, anon, authenticated;

select cron.schedule(
  'innrelay-mark-overdue-guest-reports',
  '* * * * *',
  'select private.mark_overdue_guest_reports();'
);