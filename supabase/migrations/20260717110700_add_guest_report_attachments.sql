-- Attachments for guest_reports: a private storage bucket plus a metadata
-- table, both RLS-protected using the same guest-owner / property-staff
-- pattern as guest_reports itself. Storage object paths are
-- "{report_id}/{filename}" so policies can look up the owning report.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'guest-report-attachments',
  'guest-report-attachments',
  false,
  8388608,
  array['image/jpeg','image/png','image/webp','image/heic','application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Guests or staff can upload their report's attachments"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'guest-report-attachments'
  and exists (
    select 1
    from public.guest_reports report
    where report.id::text = (storage.foldername(name))[1]
      and (report.guest_user_id = (select auth.uid()) or private.is_property_staff(report.property_id))
  )
);

create policy "Guests or staff can view their report's attachments"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'guest-report-attachments'
  and exists (
    select 1
    from public.guest_reports report
    where report.id::text = (storage.foldername(name))[1]
      and (report.guest_user_id = (select auth.uid()) or private.is_property_staff(report.property_id))
  )
);

create policy "Managers can delete their property's attachments"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'guest-report-attachments'
  and exists (
    select 1
    from public.guest_reports report
    where report.id::text = (storage.foldername(name))[1]
      and private.is_property_manager(report.property_id)
  )
);

create table public.guest_report_attachments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.guest_reports(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  storage_path text not null unique,
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp','image/heic','application/pdf')),
  size_bytes integer not null check (size_bytes > 0 and size_bytes <= 8388608),
  uploaded_by_kind text not null check (uploaded_by_kind in ('guest','staff')),
  uploaded_by_user_id uuid,
  created_at timestamptz not null default now()
);

comment on table public.guest_report_attachments is 'Metadata for files in the guest-report-attachments storage bucket. Deleting a row here does not delete the storage object -- see private.purge_expired_guest_reports for the paired cleanup.';

alter table public.guest_report_attachments enable row level security;

create index guest_report_attachments_report_idx on public.guest_report_attachments (report_id);
create index guest_report_attachments_property_idx on public.guest_report_attachments (property_id);

create policy "Guests and staff can view permitted attachments"
on public.guest_report_attachments
for select
to authenticated
using (
  exists (
    select 1 from public.guest_reports report
    where report.id = guest_report_attachments.report_id
      and (report.guest_user_id = (select auth.uid()) or private.is_property_staff(report.property_id))
  )
);

create policy "Guests or staff can attach files to permitted reports"
on public.guest_report_attachments
for insert
to authenticated
with check (
  uploaded_by_user_id = (select auth.uid())
  and exists (
    select 1 from public.guest_reports report
    where report.id = guest_report_attachments.report_id
      and report.property_id = guest_report_attachments.property_id
      and (
        (uploaded_by_kind = 'guest' and report.guest_user_id = (select auth.uid()))
        or (uploaded_by_kind = 'staff' and private.is_property_staff(report.property_id))
      )
  )
);

create policy "Managers can delete attachments on their property's reports"
on public.guest_report_attachments
for delete
to authenticated
using (private.is_property_manager(property_id));
