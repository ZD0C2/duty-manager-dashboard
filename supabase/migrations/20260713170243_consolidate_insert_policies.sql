-- Consolidate equivalent INSERT policies so Postgres evaluates one policy per
-- table/action while preserving the separate guest and staff authorization paths.

drop policy if exists "Guests can create their own report" on public.guest_reports;
drop policy if exists "Staff can create property reports" on public.guest_reports;

create policy "Guests or staff can create permitted reports"
on public.guest_reports for insert
to authenticated
with check (
  (
    guest_user_id = (select auth.uid())
    and source = 'guest'
    and status = 'reported'
    and owner_user_id is null
    and owner_display is null
    and staff_note is null
    and resolution_note is null
    and acknowledged_at is null
    and resolved_at is null
    and exists (
      select 1
      from public.properties property
      where property.id = property_id and property.active = true
    )
  )
  or private.is_property_staff(property_id)
);

drop policy if exists "Guests can add updates to their report" on public.guest_report_updates;
drop policy if exists "Staff can add updates to property reports" on public.guest_report_updates;

create policy "Guests or staff can add permitted updates"
on public.guest_report_updates for insert
to authenticated
with check (
  author_user_id = (select auth.uid())
  and (
    (
      author_kind = 'guest'
      and status is null
      and exists (
        select 1
        from public.guest_reports report
        where report.id = report_id
          and report.guest_user_id = (select auth.uid())
      )
    )
    or (
      author_kind = 'staff'
      and exists (
        select 1
        from public.guest_reports report
        where report.id = report_id
          and private.is_property_staff(report.property_id)
      )
    )
  )
);
