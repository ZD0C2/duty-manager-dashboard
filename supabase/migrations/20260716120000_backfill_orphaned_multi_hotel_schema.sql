-- Backfills schema objects that exist on the live database but were never
-- created by any recorded migration (evidently applied out-of-band, e.g. via
-- the SQL Editor, before migration-tracking was consistently used). This
-- covers the multi-hotel department/location/invitation model plus a handful
-- of columns on the original properties / property_staff / guest_reports
-- tables that later recorded migrations already assume exist.

-- properties: public_id (guest QR token), created_by (owner), data_retention_days
-- are all referenced by later recorded migrations (indexes, functions,
-- policies) but no recorded migration ever adds them.
alter table public.properties
  add column if not exists public_id uuid not null default gen_random_uuid() unique,
  add column if not exists created_by uuid references auth.users(id) on delete restrict,
  add column if not exists data_retention_days integer not null default 90
    check (data_retention_days between 30 and 730);

create table if not exists public.property_departments (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 80),
  code text not null check (code ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  response_target_minutes integer not null default 10 check (response_target_minutes between 1 and 240),
  escalation_minutes integer not null default 20 check (escalation_minutes between 2 and 1440),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, code),
  unique (property_id, id)
);

create index if not exists property_departments_property_active_idx
  on public.property_departments (property_id, active);

drop trigger if exists set_property_departments_updated_at on public.property_departments;
create trigger set_property_departments_updated_at
before update on public.property_departments
for each row execute function private.set_innrelay_property_updated_at();

alter table public.property_departments enable row level security;

drop policy if exists "Managers can add departments" on public.property_departments;
create policy "Managers can add departments"
on public.property_departments for insert
to authenticated
with check (private.is_property_manager(property_id));

drop policy if exists "Managers can remove departments" on public.property_departments;
create policy "Managers can remove departments"
on public.property_departments for delete
to authenticated
using (private.is_property_manager(property_id));

drop policy if exists "Managers can update departments" on public.property_departments;
create policy "Managers can update departments"
on public.property_departments for update
to authenticated
using (private.is_property_manager(property_id))
with check (private.is_property_manager(property_id));

drop policy if exists "Property staff can view departments" on public.property_departments;
create policy "Property staff can view departments"
on public.property_departments for select
to authenticated
using (private.is_property_staff(property_id));

grant select, insert, update, delete on public.property_departments to authenticated;

create table if not exists public.property_locations (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  department_id uuid,
  public_id uuid not null default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 100),
  code text not null check (char_length(code) between 1 and 80),
  location_type text not null default 'room' check (location_type in (
    'room', 'reception', 'bar', 'restaurant', 'gym', 'public_area', 'other',
    'entrance', 'living', 'kitchen', 'bathroom', 'bedroom', 'dining',
    'laundry', 'workspace', 'outdoor', 'parking', 'pool_hot_tub',
    'shared_area', 'whole_property'
  )),
  floor text check (floor is null or char_length(floor) <= 50),
  allows_guest_correction boolean not null default true,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (public_id),
  unique (property_id, code),
  unique (property_id, id),
  constraint property_locations_department_fkey
    foreign key (property_id, department_id)
    references public.property_departments (property_id, id)
    on delete restrict
);

create index if not exists property_locations_department_idx
  on public.property_locations (department_id) where department_id is not null;
create index if not exists property_locations_property_active_sort_idx
  on public.property_locations (property_id, active, sort_order, name);

drop trigger if exists set_property_locations_updated_at on public.property_locations;
create trigger set_property_locations_updated_at
before update on public.property_locations
for each row execute function private.set_innrelay_property_updated_at();

alter table public.property_locations enable row level security;

-- Note: the SELECT policy ("Staff and locked guests can view locations") is
-- intentionally NOT created here. Its live definition references
-- private.has_guest_portal_access (added by the recorded migration
-- 20260716121852) and properties.property_type (added by the recorded
-- migration 20260718124911, which also drops/recreates this exact policy
-- itself). Leaving it unset until that migration runs matches how the
-- policy actually came to exist and avoids depending on objects that do not
-- exist yet at this point in replay order.

drop policy if exists "Managers can remove locations" on public.property_locations;
create policy "Managers can remove locations"
on public.property_locations for delete
to authenticated
using (private.is_property_manager(property_id));

drop policy if exists "Managers can update locations" on public.property_locations;
create policy "Managers can update locations"
on public.property_locations for update
to authenticated
using (private.is_property_manager(property_id))
with check (private.is_property_manager(property_id));

drop policy if exists "Property staff can add permitted locations" on public.property_locations;
create policy "Property staff can add permitted locations"
on public.property_locations for insert
to authenticated
with check (
  private.is_property_manager(property_id)
  or (location_type = 'room' and private.is_property_staff(property_id))
);

grant select, insert, update, delete on public.property_locations to authenticated;

create table if not exists public.department_routes (
  property_id uuid not null references public.properties(id) on delete cascade,
  category_key text not null check (char_length(category_key) between 1 and 100),
  department_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (property_id, category_key),
  constraint department_routes_department_fkey
    foreign key (property_id, department_id)
    references public.property_departments (property_id, id)
    on delete cascade
);

-- department_routes_department_fkey_idx is created by the recorded migration
-- 20260716121241_optimize_multi_hotel_indexes_and_rls.sql; not duplicated here.

alter table public.department_routes enable row level security;

drop policy if exists "Managers can add routes" on public.department_routes;
create policy "Managers can add routes"
on public.department_routes for insert
to authenticated
with check (private.is_property_manager(property_id));

drop policy if exists "Managers can remove routes" on public.department_routes;
create policy "Managers can remove routes"
on public.department_routes for delete
to authenticated
using (private.is_property_manager(property_id));

drop policy if exists "Managers can update routes" on public.department_routes;
create policy "Managers can update routes"
on public.department_routes for update
to authenticated
using (private.is_property_manager(property_id))
with check (private.is_property_manager(property_id));

drop policy if exists "Property staff can view routes" on public.department_routes;
create policy "Property staff can view routes"
on public.department_routes for select
to authenticated
using (private.is_property_staff(property_id));

grant select, insert, update, delete on public.department_routes to authenticated;

-- Note: the guard_department_route_vertical trigger on this table is already
-- created by the recorded migration 20260719120500_department_routes_vertical_guard.sql.

create table if not exists public.property_invitations (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  department_id uuid,
  token uuid not null default gen_random_uuid() unique,
  email text not null check (char_length(email) between 3 and 320),
  role text not null default 'staff' check (role in ('staff', 'supervisor', 'manager')),
  active boolean not null default true,
  expires_at timestamptz not null default (now() + interval '7 days'),
  invited_by uuid not null references auth.users(id) on delete restrict,
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint property_invitations_department_fkey
    foreign key (property_id, department_id)
    references public.property_departments (property_id, id)
    on delete restrict
);

create index if not exists property_invitations_email_lower_idx
  on public.property_invitations (lower(email));
create index if not exists property_invitations_property_active_idx
  on public.property_invitations (property_id, active, expires_at);

-- property_invitations_accepted_by_idx, property_invitations_department_fkey_idx
-- and property_invitations_invited_by_idx are created by the recorded
-- migration 20260716121241_optimize_multi_hotel_indexes_and_rls.sql; not
-- duplicated here.

drop trigger if exists set_property_invitations_updated_at on public.property_invitations;
create trigger set_property_invitations_updated_at
before update on public.property_invitations
for each row execute function private.set_innrelay_property_updated_at();

alter table public.property_invitations enable row level security;

drop policy if exists "Managers and recipients can view invitations" on public.property_invitations;
create policy "Managers and recipients can view invitations"
on public.property_invitations for select
to authenticated
using (
  private.is_property_manager(property_id)
  or lower(email) = lower(coalesce((select auth.jwt()) ->> 'email', ''))
);

drop policy if exists "Managers can create invitations" on public.property_invitations;
create policy "Managers can create invitations"
on public.property_invitations for insert
to authenticated
with check (
  private.is_property_manager(property_id)
  and invited_by = (select auth.uid())
);

drop policy if exists "Managers can delete invitations" on public.property_invitations;
create policy "Managers can delete invitations"
on public.property_invitations for delete
to authenticated
using (private.is_property_manager(property_id));

drop policy if exists "Managers can update invitations" on public.property_invitations;
create policy "Managers can update invitations"
on public.property_invitations for update
to authenticated
using (private.is_property_manager(property_id))
with check (private.is_property_manager(property_id));

grant select, insert, update, delete on public.property_invitations to authenticated;

-- property_staff: department_id and invite_id are referenced by the recorded
-- migration 20260716121241_optimize_multi_hotel_indexes_and_rls.sql (its
-- "Owners managers and invitees can add memberships" policy and its
-- property_staff_department_fkey_idx index) and by
-- 20260716235918_fix_property_staff_invite_binding_policy.sql, but no
-- recorded migration ever adds these columns.
alter table public.property_staff
  add column if not exists department_id uuid,
  add column if not exists invite_id uuid unique references public.property_invitations(id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'property_staff_department_fkey'
      and conrelid = 'public.property_staff'::regclass
  ) then
    alter table public.property_staff
      add constraint property_staff_department_fkey
      foreign key (property_id, department_id)
      references public.property_departments (property_id, id)
      on delete restrict;
  end if;
end $$;

-- property_staff_department_fkey_idx is created by the recorded migration
-- 20260716121241_optimize_multi_hotel_indexes_and_rls.sql; not duplicated here.

-- guest_reports: location_id, department_id, acknowledge_due_at,
-- escalation_due_at, escalated_at and retention_delete_after are referenced
-- by the recorded migrations 20260716120846 (mark_overdue_guest_reports),
-- 20260716121241 (guest_reports_location_fkey_idx index) and by
-- private.prepare_guest_report below, but no recorded migration adds them.
alter table public.guest_reports
  add column if not exists location_id uuid,
  add column if not exists department_id uuid,
  add column if not exists acknowledge_due_at timestamptz,
  add column if not exists escalation_due_at timestamptz,
  add column if not exists escalated_at timestamptz,
  add column if not exists retention_delete_after date;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'guest_reports_location_fkey' and conrelid = 'public.guest_reports'::regclass
  ) then
    alter table public.guest_reports
      add constraint guest_reports_location_fkey
      foreign key (property_id, location_id)
      references public.property_locations (property_id, id)
      on delete restrict;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'guest_reports_department_fkey' and conrelid = 'public.guest_reports'::regclass
  ) then
    alter table public.guest_reports
      add constraint guest_reports_department_fkey
      foreign key (property_id, department_id)
      references public.property_departments (property_id, id)
      on delete restrict;
  end if;
end $$;

create index if not exists guest_reports_location_created_idx
  on public.guest_reports (location_id, created_at desc)
  where location_id is not null;
create index if not exists guest_reports_property_department_open_idx
  on public.guest_reports (property_id, department_id, escalation_due_at)
  where status not in ('resolved', 'closed', 'cancelled', 'duplicate');

-- guest_reports_location_fkey_idx is created by the recorded migration
-- 20260716121241_optimize_multi_hotel_indexes_and_rls.sql; not duplicated here.

create table if not exists public.guest_portal_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  location_id uuid not null,
  property_token uuid not null,
  location_token uuid not null,
  expires_at timestamptz not null default (now() + interval '8 days'),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, property_id, location_id),
  constraint guest_portal_sessions_location_fkey
    foreign key (property_id, location_id)
    references public.property_locations (property_id, id)
    on delete cascade
);

create index if not exists guest_portal_sessions_property_location_idx
  on public.guest_portal_sessions (property_id, location_id, user_id);
create index if not exists guest_portal_sessions_user_active_idx
  on public.guest_portal_sessions (user_id, expires_at, property_id);

alter table public.guest_portal_sessions enable row level security;

-- Note: guest_portal_sessions' own policies are NOT created here. They
-- reference private.valid_guest_portal_tokens, which itself needs
-- properties.public_id (added above) and property_locations.public_id, and
-- is only created in the follow-up migration
-- 20260716122000_backfill_guest_portal_sessions_policies.sql, placed after
-- the recorded migration 20260716121852 (which introduces
-- private.has_guest_portal_access, the other function these policies could
-- plausibly need).

grant select, insert, update, delete on public.guest_portal_sessions to authenticated;

create table if not exists private.guest_submission_events (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  property_id uuid not null,
  created_at timestamptz not null default now()
);

create index if not exists guest_submission_events_limit_idx
  on private.guest_submission_events (user_id, property_id, created_at desc);

-- private.guest_submission_events follows the standard pattern for this
-- schema (revoke all on schema private from public, reachable only through
-- SECURITY DEFINER functions): RLS is not enabled and no grants are made,
-- matching the live table and its private-schema siblings
-- (guest_abuse_events, notification_deliveries).

create or replace function private.is_property_owner(target_property_id uuid)
returns boolean
language sql
stable security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.property_staff membership
    where membership.property_id = target_property_id
      and membership.user_id = (select auth.uid())
      and membership.active = true
      and membership.role = 'owner'
  );
$function$;

revoke all on function private.is_property_owner(uuid) from public;
grant execute on function private.is_property_owner(uuid) to authenticated;

create or replace function private.can_bootstrap_property_owner(target_property_id uuid)
returns boolean
language sql
stable security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.properties property
    where property.id = target_property_id
      and property.created_by = (select auth.uid())
      and not exists (
        select 1
        from public.property_staff membership
        where membership.property_id = property.id
      )
  );
$function$;

revoke all on function private.can_bootstrap_property_owner(uuid) from public;
grant execute on function private.can_bootstrap_property_owner(uuid) to authenticated;

create or replace function private.accept_property_invitation()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  invitation public.property_invitations%rowtype;
  signed_in_email text := lower(coalesce((select auth.jwt()->>'email'), ''));
begin
  if new.invite_id is null then
    return new;
  end if;

  select * into invitation
  from public.property_invitations
  where id = new.invite_id
  for update;

  if invitation.id is null
     or invitation.active is not true
     or invitation.accepted_at is not null
     or invitation.expires_at <= now()
     or lower(invitation.email) <> signed_in_email
     or new.user_id <> (select auth.uid())
     or new.property_id <> invitation.property_id
     or new.role <> invitation.role
     or new.department_id is distinct from invitation.department_id then
    raise exception 'This staff invitation is invalid, expired or belongs to another account.';
  end if;

  update public.property_invitations
  set accepted_by = new.user_id,
      accepted_at = now(),
      active = false,
      updated_at = now()
  where id = invitation.id;

  return new;
end;
$function$;

drop trigger if exists accept_property_invitation on public.property_staff;
create trigger accept_property_invitation
before insert on public.property_staff
for each row execute function private.accept_property_invitation();

create or replace function private.create_property_owner_membership()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  owner_name text;
begin
  owner_name := coalesce(
    nullif((select auth.jwt()->'user_metadata'->>'full_name'), ''),
    nullif((select auth.jwt()->'user_metadata'->>'name'), ''),
    nullif(split_part(coalesce((select auth.jwt()->>'email'), ''), '@', 1), ''),
    'Property owner'
  );
  insert into public.property_staff (property_id, user_id, display_name, role, active)
  values (new.id, new.created_by, left(owner_name, 100), 'owner', true)
  on conflict (property_id, user_id) do nothing;
  return new;
end;
$function$;

drop trigger if exists create_property_owner_membership on public.properties;
create trigger create_property_owner_membership
after insert on public.properties
for each row execute function private.create_property_owner_membership();
