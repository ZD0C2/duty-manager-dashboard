-- InnRelay guest-to-staff pilot
-- Supabase Postgres 17 / publishable-key clients / RLS on every exposed table.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  reception_phone text,
  emergency_notice text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.property_staff (
  property_id uuid not null references public.properties(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 100),
  role text not null default 'staff' check (role in ('staff', 'supervisor', 'manager', 'owner')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (property_id, user_id)
);

create table if not exists public.guest_reports (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete restrict,
  guest_user_id uuid references auth.users(id) on delete set null,
  source text not null default 'guest' check (source in ('guest', 'staff')),
  location text not null check (char_length(location) between 1 and 80),
  category_key text not null check (char_length(category_key) between 1 and 100),
  category_label text not null check (char_length(category_label) between 1 and 140),
  issue_code text not null check (char_length(issue_code) between 1 and 190),
  title text not null check (char_length(title) between 1 and 140),
  description text not null default '' check (char_length(description) <= 1200),
  urgency text not null default 'normal' check (urgency in ('normal', 'soon', 'urgent', 'emergency')),
  guest_impact text not null default 'guest_affected' check (guest_impact in ('none_yet', 'guest_affected', 'guest_waiting', 'room_out_of_order')),
  guest_name text check (guest_name is null or char_length(guest_name) <= 80),
  contact_preference text not null default 'app' check (contact_preference in ('app', 'room-phone', 'reception')),
  status text not null default 'reported' check (status in ('reported', 'acknowledged', 'in_progress', 'waiting_guest', 'resolved', 'closed', 'cancelled', 'duplicate')),
  owner_user_id uuid references auth.users(id) on delete set null,
  owner_display text check (owner_display is null or char_length(owner_display) <= 100),
  staff_note text check (staff_note is null or char_length(staff_note) <= 1200),
  resolution_note text check (resolution_note is null or char_length(resolution_note) <= 1200),
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.guest_report_updates (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.guest_reports(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete restrict,
  author_kind text not null check (author_kind in ('guest', 'staff')),
  message text not null check (char_length(message) between 1 and 1200),
  status text check (status is null or status in ('reported', 'acknowledged', 'in_progress', 'waiting_guest', 'resolved', 'closed', 'cancelled', 'duplicate')),
  created_at timestamptz not null default now()
);

create index if not exists guest_reports_property_status_created_idx
  on public.guest_reports (property_id, status, created_at desc);
create index if not exists guest_reports_property_created_idx
  on public.guest_reports (property_id, created_at desc);
create index if not exists guest_reports_property_open_created_idx
  on public.guest_reports (property_id, created_at desc)
  where status not in ('resolved', 'closed', 'cancelled', 'duplicate');
create index if not exists property_staff_user_active_idx
  on public.property_staff (user_id, property_id) where active = true;
create index if not exists guest_reports_guest_created_idx
  on public.guest_reports (guest_user_id, created_at desc);
create index if not exists guest_reports_owner_status_idx
  on public.guest_reports (owner_user_id, status) where owner_user_id is not null;
create index if not exists guest_report_updates_report_created_idx
  on public.guest_report_updates (report_id, created_at);
create index if not exists guest_report_updates_author_idx
  on public.guest_report_updates (author_user_id);

create or replace function private.is_property_staff(target_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.property_staff membership
    where membership.property_id = target_property_id
      and membership.user_id = (select auth.uid())
      and membership.active = true
  );
$$;

create or replace function private.is_property_manager(target_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.property_staff membership
    where membership.property_id = target_property_id
      and membership.user_id = (select auth.uid())
      and membership.active = true
      and membership.role in ('manager', 'owner')
  );
$$;

revoke all on function private.is_property_staff(uuid) from public;
revoke all on function private.is_property_manager(uuid) from public;
grant execute on function private.is_property_staff(uuid) to authenticated;
grant execute on function private.is_property_manager(uuid) to authenticated;

create or replace function private.set_innrelay_report_timestamps()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  if new.status in ('acknowledged', 'in_progress', 'waiting_guest', 'resolved', 'closed')
     and old.status = 'reported'
     and new.acknowledged_at is null then
    new.acknowledged_at := now();
  end if;
  if new.status in ('resolved', 'closed') and old.status not in ('resolved', 'closed') then
    new.resolved_at := coalesce(new.resolved_at, now());
  elsif new.status not in ('resolved', 'closed') then
    new.resolved_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists set_innrelay_report_timestamps on public.guest_reports;
create trigger set_innrelay_report_timestamps
before update on public.guest_reports
for each row execute function private.set_innrelay_report_timestamps();

create or replace function private.set_innrelay_property_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_innrelay_property_updated_at on public.properties;
create trigger set_innrelay_property_updated_at
before update on public.properties
for each row execute function private.set_innrelay_property_updated_at();

alter table public.properties enable row level security;
alter table public.property_staff enable row level security;
alter table public.guest_reports enable row level security;
alter table public.guest_report_updates enable row level security;

drop policy if exists "Authenticated users can view active properties" on public.properties;
create policy "Authenticated users can view active properties"
on public.properties for select
to authenticated
using (active = true or private.is_property_staff(id));

drop policy if exists "Managers can update their property" on public.properties;
create policy "Managers can update their property"
on public.properties for update
to authenticated
using (private.is_property_manager(id))
with check (private.is_property_manager(id));

drop policy if exists "Staff can view relevant memberships" on public.property_staff;
create policy "Staff can view relevant memberships"
on public.property_staff for select
to authenticated
using (user_id = (select auth.uid()) or private.is_property_manager(property_id));

drop policy if exists "Managers can add property staff" on public.property_staff;
create policy "Managers can add property staff"
on public.property_staff for insert
to authenticated
with check (private.is_property_manager(property_id));

drop policy if exists "Managers can update property staff" on public.property_staff;
create policy "Managers can update property staff"
on public.property_staff for update
to authenticated
using (private.is_property_manager(property_id))
with check (private.is_property_manager(property_id));

drop policy if exists "Managers can remove property staff" on public.property_staff;
create policy "Managers can remove property staff"
on public.property_staff for delete
to authenticated
using (private.is_property_manager(property_id));

drop policy if exists "Guests can create their own report" on public.guest_reports;
create policy "Guests can create their own report"
on public.guest_reports for insert
to authenticated
with check (
  guest_user_id = (select auth.uid())
  and source = 'guest'
  and status = 'reported'
  and owner_user_id is null
  and owner_display is null
  and staff_note is null
  and resolution_note is null
  and acknowledged_at is null
  and resolved_at is null
  and exists (select 1 from public.properties property where property.id = property_id and property.active = true)
);

drop policy if exists "Staff can create property reports" on public.guest_reports;
create policy "Staff can create property reports"
on public.guest_reports for insert
to authenticated
with check (private.is_property_staff(property_id));

drop policy if exists "Guests and staff can view permitted reports" on public.guest_reports;
create policy "Guests and staff can view permitted reports"
on public.guest_reports for select
to authenticated
using (guest_user_id = (select auth.uid()) or private.is_property_staff(property_id));

drop policy if exists "Staff can update property reports" on public.guest_reports;
create policy "Staff can update property reports"
on public.guest_reports for update
to authenticated
using (private.is_property_staff(property_id))
with check (private.is_property_staff(property_id));

drop policy if exists "Managers can delete property reports" on public.guest_reports;
create policy "Managers can delete property reports"
on public.guest_reports for delete
to authenticated
using (private.is_property_manager(property_id));

drop policy if exists "Guests and staff can view permitted updates" on public.guest_report_updates;
create policy "Guests and staff can view permitted updates"
on public.guest_report_updates for select
to authenticated
using (
  exists (
    select 1 from public.guest_reports report
    where report.id = report_id
      and (report.guest_user_id = (select auth.uid()) or private.is_property_staff(report.property_id))
  )
);

drop policy if exists "Guests can add updates to their report" on public.guest_report_updates;
create policy "Guests can add updates to their report"
on public.guest_report_updates for insert
to authenticated
with check (
  author_user_id = (select auth.uid())
  and author_kind = 'guest'
  and status is null
  and exists (
    select 1 from public.guest_reports report
    where report.id = report_id and report.guest_user_id = (select auth.uid())
  )
);

drop policy if exists "Staff can add updates to property reports" on public.guest_report_updates;
create policy "Staff can add updates to property reports"
on public.guest_report_updates for insert
to authenticated
with check (
  author_user_id = (select auth.uid())
  and author_kind = 'staff'
  and exists (
    select 1 from public.guest_reports report
    where report.id = report_id and private.is_property_staff(report.property_id)
  )
);

-- Supabase projects created after April 2026 may not expose SQL-created tables
-- automatically, so permissions are explicit as well as protected by RLS.
grant select on public.properties to authenticated;
grant select, insert, update, delete on public.property_staff to authenticated;
grant select, insert, update, delete on public.guest_reports to authenticated;
grant select, insert on public.guest_report_updates to authenticated;

insert into public.properties (name, slug, reception_phone, emergency_notice)
values (
  'Exhibition Court Hotel',
  'exhibition-court',
  'Use the room phone and select Reception',
  'For immediate danger call reception and emergency services before using the app.'
)
on conflict (slug) do update set
  name = excluded.name,
  reception_phone = excluded.reception_phone,
  emergency_notice = excluded.emergency_notice,
  active = true;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'guest_reports'
  ) then
    alter publication supabase_realtime add table public.guest_reports;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'guest_report_updates'
  ) then
    alter publication supabase_realtime add table public.guest_report_updates;
  end if;
end;
$$;

comment on table public.guest_reports is 'Guest and staff hotel issue records for InnRelay.';
comment on column public.guest_reports.guest_user_id is 'Supabase anonymous or permanent user that created the guest report.';
comment on table public.guest_report_updates is 'Append-only guest/staff conversation and status history.';
