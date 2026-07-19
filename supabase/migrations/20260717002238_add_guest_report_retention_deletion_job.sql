-- Retention deletion for guest_reports past their retention_delete_after date.
-- This is deliberately not a bare DELETE: every purge writes a minimal,
-- non-identifying audit row first (retention_deletions), counts the
-- dependent guest_report_updates it removes, and defensively cleans up a
-- future guest_report_attachments table (and its rows) if one ever exists,
-- without erroring today since that table does not exist yet.

create table if not exists public.retention_deletions (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  report_id uuid not null,
  category_key text,
  report_created_at timestamptz,
  updates_deleted integer not null default 0,
  attachments_deleted integer not null default 0,
  reason text not null default 'retention_period_elapsed',
  deleted_at timestamptz not null default now()
);

comment on table public.retention_deletions is
  'Audit trail for guest_reports purged by the retention-deletion job. Holds no guest-identifying content on purpose -- only enough metadata to prove what was deleted, when, and why.';

alter table public.retention_deletions enable row level security;

create policy "Managers can view their property retention log"
on public.retention_deletions
for select
to authenticated
using (private.is_property_manager(property_id));

create index if not exists retention_deletions_property_deleted_idx
  on public.retention_deletions (property_id, deleted_at desc);

create or replace function private.purge_expired_guest_reports()
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  expired_report record;
  purged_count integer := 0;
  update_count integer;
  attachment_count integer;
  has_attachments boolean;
begin
  has_attachments := to_regclass('public.guest_report_attachments') is not null;

  for expired_report in
    select id, property_id, category_key, created_at
    from public.guest_reports
    where retention_delete_after is not null
      and retention_delete_after <= current_date
    order by retention_delete_after
    limit 500
  loop
    begin
      select count(*) into update_count
      from public.guest_report_updates
      where report_id = expired_report.id;

      attachment_count := 0;
      if has_attachments then
        begin
          execute 'select count(*) from public.guest_report_attachments where report_id = $1'
            into attachment_count
            using expired_report.id;
          execute 'delete from public.guest_report_attachments where report_id = $1'
            using expired_report.id;
        exception when others then
          attachment_count := 0;
        end;
      end if;

      insert into public.retention_deletions (
        property_id, report_id, category_key, report_created_at,
        updates_deleted, attachments_deleted, reason
      ) values (
        expired_report.property_id, expired_report.id, expired_report.category_key, expired_report.created_at,
        update_count, attachment_count, 'retention_period_elapsed'
      );

      -- guest_report_updates cascades on this delete (ON DELETE CASCADE),
      -- which is why its count is captured above before the row is gone.
      delete from public.guest_reports where id = expired_report.id;

      purged_count := purged_count + 1;
    exception when others then
      -- One malformed row must not block the rest of the retention run.
      continue;
    end;
  end loop;

  return purged_count;
end;
$function$;

select cron.schedule(
  'innrelay-purge-expired-guest-reports',
  '17 3 * * *',
  $$select private.purge_expired_guest_reports();$$
);
