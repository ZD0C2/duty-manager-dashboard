-- Now that guest_report_attachments and its storage bucket exist,
-- extend the retention job to delete the actual storage objects for a
-- purged report, not just its attachment metadata rows -- otherwise
-- guest photos would silently outlive the "deleted" report forever.

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
          select count(*) into attachment_count
          from public.guest_report_attachments
          where report_id = expired_report.id;

          delete from storage.objects
          where bucket_id = 'guest-report-attachments'
            and (storage.foldername(name))[1] = expired_report.id::text;

          delete from public.guest_report_attachments
          where report_id = expired_report.id;
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

      -- guest_report_updates and guest_report_attachments cascade on this
      -- delete too; the explicit attachment deletes above exist only to
      -- also remove the storage objects, which cascade does not reach.
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
